package com.hoho.android.usbserial.driver;
import android.hardware.usb.UsbDeviceConnection;
import java.io.IOException;
// SO PARA COMPILAR (assinaturas de usb-serial-for-android 3.11.0); nao vai no .aar.
public interface UsbSerialPort {
    int DATABITS_8 = 8;
    int PARITY_NONE = 0;
    int STOPBITS_1 = 1;
    void open(UsbDeviceConnection connection) throws IOException;
    void close() throws IOException;
    int read(final byte[] dest, final int timeout) throws IOException;
    void write(final byte[] src, final int timeout) throws IOException;
    void setParameters(int baudRate, int dataBits, int stopBits, int parity) throws IOException;
    void setDTR(boolean value) throws IOException;
    void setRTS(boolean value) throws IOException;
    boolean isOpen();
}
