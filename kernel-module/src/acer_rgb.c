// SPDX-License-Identifier: GPL-2.0
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/acpi.h>
#include <linux/wmi.h>
#include <linux/dmi.h>
#include <linux/platform_device.h>
#include <linux/string.h>

#define PREDATOR_WMI_GUID "7A4DDFE7-5B5D-40B4-8595-4408E0CC7F56"
#define PREDATOR_MAX_ZONES 4
#define WMI_PAYLOAD_SIZE 16

#define WMI_SET_KB_MODE     0x14
#define WMI_SET_KB_ZONE     0x06
#define WMI_SET_BACK_LOGO   0x0C

MODULE_LICENSE("GPL");
MODULE_AUTHOR("skvggor");
MODULE_DESCRIPTION("RGB LED control for Acer Predator PHN16-72 via WMI");
MODULE_VERSION("0.2.2");

static struct platform_device *acer_rgb_pdev;

struct acer_rgb_zone {
    u8 red;
    u8 green;
    u8 blue;
};

static struct acer_rgb_zone acer_rgb_zones[PREDATOR_MAX_ZONES];
static u8 acer_rgb_brightness;

static struct acer_rgb_zone acer_rgb_back_logo;
static u8 acer_rgb_back_logo_brightness;
static int acer_rgb_back_logo_enabled;

static int wmi_send(u32 method_id, const u8 *data, size_t len)
{
    struct acpi_buffer input = { len, (void *)data };
    struct acpi_buffer result = { ACPI_ALLOCATE_BUFFER, NULL };
    acpi_status status;

    status = wmi_evaluate_method(PREDATOR_WMI_GUID, 0, method_id,
                                 &input, &result);
    if (ACPI_FAILURE(status))
        return -EIO;

    kfree(result.pointer);
    return 0;
}

static int set_kb_mode(int brightness)
{
    u64 resp = 0;
    u8 payload[WMI_PAYLOAD_SIZE] = {
        0, 0, (u8)brightness, 0, 0,
        0, 0, 0, 3, 1, 0, 0, 0, 0, 0, 0
    };
    acpi_status status;
    union acpi_object *obj;
    struct acpi_buffer output = { ACPI_ALLOCATE_BUFFER, NULL };
    struct acpi_buffer input = { WMI_PAYLOAD_SIZE, payload };

    status = wmi_evaluate_method(PREDATOR_WMI_GUID, 0, WMI_SET_KB_MODE,
                                 &input, &output);
    if (ACPI_FAILURE(status))
        return -EIO;

    obj = output.pointer;
    if (obj) {
        if (obj->type == ACPI_TYPE_BUFFER) {
            if (obj->buffer.length == sizeof(u32))
                resp = *((u32 *)obj->buffer.pointer);
            else if (obj->buffer.length == sizeof(u64))
                resp = *((u64 *)obj->buffer.pointer);
        } else if (obj->type == ACPI_TYPE_INTEGER) {
            resp = obj->integer.value;
        }
        kfree(obj);
    }

    if (resp != 0)
        return -EIO;

    return 0;
}

static int set_zone_color(u8 zone_mask, u8 red, u8 green, u8 blue)
{
    u8 payload[4] = { zone_mask, red, green, blue };
    struct acpi_buffer input = { sizeof(payload), payload };
    acpi_status status;

    status = wmi_evaluate_method(PREDATOR_WMI_GUID, 0, WMI_SET_KB_ZONE,
                                 &input, NULL);
    if (ACPI_FAILURE(status))
        return -EIO;

    return 0;
}

static int apply_zone(int zone_id)
{
    if (zone_id < 1 || zone_id > PREDATOR_MAX_ZONES)
        return -EINVAL;

    return set_zone_color((u8)(1 << (zone_id - 1)),
                          acer_rgb_zones[zone_id - 1].red,
                          acer_rgb_zones[zone_id - 1].green,
                          acer_rgb_zones[zone_id - 1].blue);
}

static int apply_keyboard_zones(void)
{
    int i, ret;

    ret = set_kb_mode(acer_rgb_brightness);
    if (ret != 0)
        return ret;

    for (i = 0; i < PREDATOR_MAX_ZONES; i++) {
        ret = apply_zone(i + 1);
        if (ret != 0)
            return ret;
    }

    return 0;
}

static int apply_back_logo(void)
{
    u8 payload[6];
    u8 power_payload[WMI_PAYLOAD_SIZE];
    int ret;

    payload[0] = 0x01;
    payload[1] = acer_rgb_back_logo.red;
    payload[2] = acer_rgb_back_logo.green;
    payload[3] = acer_rgb_back_logo.blue;
    payload[4] = acer_rgb_back_logo_brightness;
    payload[5] = acer_rgb_back_logo_enabled ? 0x01 : 0x00;

    ret = wmi_send(WMI_SET_BACK_LOGO, payload, sizeof(payload));
    if (ret != 0)
        return ret;

    memset(power_payload, 0, WMI_PAYLOAD_SIZE);
    power_payload[0] = acer_rgb_back_logo_enabled ? 0x01 : 0x00;
    power_payload[9] = 0x02;

    return wmi_send(WMI_SET_KB_MODE, power_payload, WMI_PAYLOAD_SIZE);
}

static int parse_hex_color(const char *hex, int *red, int *green, int *blue)
{
    char buf[3];
    int val;

    if (strlen(hex) != 6)
        return -EINVAL;

    buf[2] = '\0';

    buf[0] = hex[0];
    buf[1] = hex[1];
    if (kstrtoint(buf, 16, &val) < 0)
        return -EINVAL;
    *red = val;

    buf[0] = hex[2];
    buf[1] = hex[3];
    if (kstrtoint(buf, 16, &val) < 0)
        return -EINVAL;
    *green = val;

    buf[0] = hex[4];
    buf[1] = hex[5];
    if (kstrtoint(buf, 16, &val) < 0)
        return -EINVAL;
    *blue = val;

    return 0;
}

static ssize_t per_zone_mode_store(struct device *dev,
                                   struct device_attribute *attr,
                                   const char *buf, size_t count)
{
    char *input, *next;
    int red, green, blue;
    int brightness_val;
    int i, ret;

    input = kstrdup(buf, GFP_KERNEL);
    if (!input)
        return -ENOMEM;

    next = input;
    strim(next);

    for (i = 0; i < PREDATOR_MAX_ZONES; i++) {
        char *sep = strchr(next, ',');
        if (!sep) {
            kfree(input);
            return -EINVAL;
        }
        *sep = '\0';

        ret = parse_hex_color(next, &red, &green, &blue);
        if (ret < 0) {
            kfree(input);
            return ret;
        }
        acer_rgb_zones[i].red = (u8)red;
        acer_rgb_zones[i].green = (u8)green;
        acer_rgb_zones[i].blue = (u8)blue;
        next = sep + 1;
    }

    strim(next);
    if (kstrtoint(next, 10, &brightness_val) < 0) {
        kfree(input);
        return -EINVAL;
    }

    if (brightness_val < 0 || brightness_val > 100) {
        kfree(input);
        return -EINVAL;
    }

    acer_rgb_brightness = (u8)brightness_val;

    ret = apply_keyboard_zones();
    if (ret != 0) {
        kfree(input);
        return ret;
    }

    kfree(input);
    return count;
}

static ssize_t per_zone_mode_show(struct device *dev,
                                  struct device_attribute *attr, char *buf)
{
    return sysfs_emit(buf, "%02x%02x%02x,%02x%02x%02x,%02x%02x%02x,%02x%02x%02x,%d\n",
                      acer_rgb_zones[0].red, acer_rgb_zones[0].green, acer_rgb_zones[0].blue,
                      acer_rgb_zones[1].red, acer_rgb_zones[1].green, acer_rgb_zones[1].blue,
                      acer_rgb_zones[2].red, acer_rgb_zones[2].green, acer_rgb_zones[2].blue,
                      acer_rgb_zones[3].red, acer_rgb_zones[3].green, acer_rgb_zones[3].blue,
                      acer_rgb_brightness);
}

static DEVICE_ATTR_RW(per_zone_mode);

static ssize_t back_logo_store(struct device *dev,
                               struct device_attribute *attr,
                               const char *buf, size_t count)
{
    char *input, *next;
    int red, green, blue;
    int brightness_val, enable_val;
    int ret;

    input = kstrdup(buf, GFP_KERNEL);
    if (!input)
        return -ENOMEM;

    next = input;
    strim(next);

    char *sep = strchr(next, ',');
    if (!sep) {
        kfree(input);
        return -EINVAL;
    }
    *sep = '\0';

    ret = parse_hex_color(next, &red, &green, &blue);
    if (ret < 0) {
        kfree(input);
        return ret;
    }
    next = sep + 1;

    sep = strchr(next, ',');
    if (!sep) {
        kfree(input);
        return -EINVAL;
    }
    *sep = '\0';

    if (kstrtoint(next, 10, &brightness_val) < 0) {
        kfree(input);
        return -EINVAL;
    }
    next = sep + 1;

    strim(next);
    if (kstrtoint(next, 10, &enable_val) < 0) {
        kfree(input);
        return -EINVAL;
    }

    if (brightness_val < 0 || brightness_val > 100) {
        kfree(input);
        return -EINVAL;
    }

    acer_rgb_back_logo.red = (u8)red;
    acer_rgb_back_logo.green = (u8)green;
    acer_rgb_back_logo.blue = (u8)blue;
    acer_rgb_back_logo_brightness = (u8)brightness_val;
    acer_rgb_back_logo_enabled = enable_val ? 1 : 0;

    ret = apply_back_logo();
    kfree(input);
    return (ret != 0) ? ret : count;
}

static ssize_t back_logo_show(struct device *dev,
                              struct device_attribute *attr, char *buf)
{
    return sysfs_emit(buf, "%02x%02x%02x,%d,%d\n",
                      acer_rgb_back_logo.red, acer_rgb_back_logo.green,
                      acer_rgb_back_logo.blue,
                      acer_rgb_back_logo_brightness,
                      acer_rgb_back_logo_enabled);
}

static DEVICE_ATTR_RW(back_logo);

static struct attribute *four_zoned_kb_attrs[] = {
    &dev_attr_per_zone_mode.attr,
    &dev_attr_back_logo.attr,
    NULL,
};

static const struct attribute_group four_zoned_kb_attr_group = {
    .attrs = four_zoned_kb_attrs,
    .name = "four_zoned_kb",
};

static int acer_rgb_probe(struct platform_device *pdev)
{
    int i, ret;

    for (i = 0; i < PREDATOR_MAX_ZONES; i++) {
        acer_rgb_zones[i].red = 0;
        acer_rgb_zones[i].green = 0;
        acer_rgb_zones[i].blue = 0;
    }
    acer_rgb_brightness = 0;

    acer_rgb_back_logo.red = 0;
    acer_rgb_back_logo.green = 0;
    acer_rgb_back_logo.blue = 0;
    acer_rgb_back_logo_brightness = 0;
    acer_rgb_back_logo_enabled = 0;

    ret = sysfs_create_group(&pdev->dev.kobj, &four_zoned_kb_attr_group);
    if (ret) {
        dev_err(&pdev->dev, "failed to create sysfs group\n");
        return ret;
    }

    dev_info(&pdev->dev, "acer_rgb driver probed\n");
    return 0;
}

static void acer_rgb_remove(struct platform_device *pdev)
{
    sysfs_remove_group(&pdev->dev.kobj, &four_zoned_kb_attr_group);
    dev_info(&pdev->dev, "acer_rgb driver removed\n");
}

static struct platform_driver acer_rgb_driver = {
    .driver = {
        .name = "acer_rgb",
    },
    .probe = acer_rgb_probe,
    .remove = acer_rgb_remove,
};

static const struct dmi_system_id predator_dmi_table[] = {
    {
        .callback = NULL,
        .ident = "Acer Predator PHN16-72",
        .matches = {
            DMI_MATCH(DMI_SYS_VENDOR, "Acer"),
            DMI_MATCH(DMI_PRODUCT_NAME, "Predator PHN16-72"),
        },
    },
    { }
};
MODULE_DEVICE_TABLE(dmi, predator_dmi_table);

static int __init acer_rgb_init(void)
{
    int ret;

    if (!dmi_check_system(predator_dmi_table)) {
        pr_info("acer_rgb: not a PHN16-72, skipping\n");
        return -ENODEV;
    }

    if (!wmi_has_guid(PREDATOR_WMI_GUID)) {
        pr_err("acer_rgb: WMI GUID %s not found\n", PREDATOR_WMI_GUID);
        return -ENODEV;
    }

    ret = platform_driver_register(&acer_rgb_driver);
    if (ret) {
        pr_err("acer_rgb: failed to register platform driver\n");
        return ret;
    }

    acer_rgb_pdev = platform_device_register_simple("acer_rgb", -1, NULL, 0);
    if (IS_ERR(acer_rgb_pdev)) {
        platform_driver_unregister(&acer_rgb_driver);
        pr_err("acer_rgb: failed to register platform device\n");
        return PTR_ERR(acer_rgb_pdev);
    }

    pr_info("acer_rgb: module loaded successfully\n");
    return 0;
}

static void __exit acer_rgb_exit(void)
{
    platform_device_unregister(acer_rgb_pdev);
    platform_driver_unregister(&acer_rgb_driver);
    pr_info("acer_rgb: module unloaded\n");
}

module_init(acer_rgb_init);
module_exit(acer_rgb_exit);
