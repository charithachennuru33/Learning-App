package com.company.platform.auth.service;

import com.company.platform.common.error.ApiException;
import com.company.platform.common.error.ErrorCode;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class PhoneNumberNormalizerTest {
    private final PhoneNumberNormalizer normalizer = new PhoneNumberNormalizer("IN");

    @ParameterizedTest
    @ValueSource(strings = {"9876543210", "98765 43210", "+91 98765-43210", "+919876543210", "09876543210"})
    void formatsIndianMobileVariantsToOneE164Value(String input) {
        assertThat(normalizer.normalize(input)).isEqualTo("+919876543210");
    }

    @Test
    void keepsExplicitForeignCountryCode() {
        assertThat(normalizer.normalize("+1 415 555 2671")).isEqualTo("+14155552671");
    }

    @ParameterizedTest
    @ValueSource(strings = {"", "   ", "abc", "12345", "+91 12345 67890", "99999999999999999"})
    void rejectsInvalidNumbers(String input) {
        assertThatThrownBy(() -> normalizer.normalize(input))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).code())
                .isEqualTo(ErrorCode.INVALID_PHONE_NUMBER);
    }

    @Test
    void masksAllButCountryPrefixAndLastFourDigits() {
        assertThat(PhoneNumberNormalizer.mask("+919876543210")).isEqualTo("+91******3210");
        assertThat(PhoneNumberNormalizer.mask(null)).isEqualTo("***");
    }
}
