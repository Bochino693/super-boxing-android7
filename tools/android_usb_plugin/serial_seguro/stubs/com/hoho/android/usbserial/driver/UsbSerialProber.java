package com.hoho.android.usbserial.driver;
import android.hardware.usb.UsbManager;
import java.util.List;
public class UsbSerialProber {
    public static UsbSerialProber getDefaultProber() { return null; }
    public List<UsbSerialDriver> findAllDrivers(final UsbManager usbManager) { return null; }
}
