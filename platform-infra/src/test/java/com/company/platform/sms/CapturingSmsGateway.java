package com.company.platform.sms;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/** Test double that records the last OTP per phone, and can simulate a provider outage. */
public class CapturingSmsGateway implements SmsGateway {
    private final Map<String, String> lastOtp = new ConcurrentHashMap<>();
    private volatile boolean failing;

    @Override
    public void sendOtp(String e164Phone, String otp) {
        if (failing) throw new SmsDeliveryException("simulated outage", null);
        lastOtp.put(e164Phone, otp);
    }

    public String lastOtp(String e164Phone) { return lastOtp.get(e164Phone); }

    public void setFailing(boolean failing) { this.failing = failing; }

    public void reset() {
        lastOtp.clear();
        failing = false;
    }
}
