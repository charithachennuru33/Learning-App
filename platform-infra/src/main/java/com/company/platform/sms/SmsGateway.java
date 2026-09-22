package com.company.platform.sms;

public interface SmsGateway {
    /**
     * Sends the OTP to an E.164 phone number.
     *
     * @throws SmsDeliveryException if the provider rejected or could not be reached
     */
    void sendOtp(String e164Phone, String otp);
}
