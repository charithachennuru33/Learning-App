package com.company.platform.sms;

public interface SmsGateway {

    void sendOtp(String destination, String otp);
}
