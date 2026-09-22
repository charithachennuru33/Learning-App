package com.company.platform.auth.service;

import com.company.platform.auth.config.AuthProperties;
import com.company.platform.common.error.ApiException;
import com.company.platform.common.error.ErrorCode;
import com.google.i18n.phonenumbers.NumberParseException;
import com.google.i18n.phonenumbers.PhoneNumberUtil;
import com.google.i18n.phonenumbers.PhoneNumberUtil.PhoneNumberFormat;
import com.google.i18n.phonenumbers.PhoneNumberUtil.PhoneNumberType;
import com.google.i18n.phonenumbers.Phonenumber.PhoneNumber;
import org.springframework.stereotype.Component;

import java.util.Set;

/** Canonicalises user input to E.164 so "98765 43210", "+91-9876543210" and "09876543210" are one account. */
@Component
public class PhoneNumberNormalizer {
    private static final PhoneNumberUtil UTIL = PhoneNumberUtil.getInstance();
    private static final Set<PhoneNumberType> SMS_CAPABLE =
            Set.of(PhoneNumberType.MOBILE, PhoneNumberType.FIXED_LINE_OR_MOBILE);

    private final String defaultRegion;

    public PhoneNumberNormalizer(AuthProperties props) { this(props.defaultRegion()); }

    PhoneNumberNormalizer(String defaultRegion) { this.defaultRegion = defaultRegion; }

    public String normalize(String raw) {
        if (raw == null || raw.isBlank()) throw new ApiException(ErrorCode.INVALID_PHONE_NUMBER);
        try {
            PhoneNumber number = UTIL.parse(raw.trim(), defaultRegion);
            if (!UTIL.isValidNumber(number) || !SMS_CAPABLE.contains(UTIL.getNumberType(number))) {
                throw new ApiException(ErrorCode.INVALID_PHONE_NUMBER);
            }
            return UTIL.format(number, PhoneNumberFormat.E164);
        } catch (NumberParseException e) {
            throw new ApiException(ErrorCode.INVALID_PHONE_NUMBER);
        }
    }

    /** "+919876543210" becomes "+91******3210", for logs and audit rows. */
    public static String mask(String e164) {
        if (e164 == null || e164.length() < 7) return "***";
        return e164.substring(0, 3) + "*".repeat(e164.length() - 7) + e164.substring(e164.length() - 4);
    }
}
