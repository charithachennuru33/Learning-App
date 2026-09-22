package com.company.platform.common.api;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record ApiResponse<T>(boolean success, T data, String message, ApiError error) {
    public static <T> ApiResponse<T> ok(T data) { return new ApiResponse<>(true, data, null, null); }
    public static <T> ApiResponse<T> ok(T data, String message) { return new ApiResponse<>(true, data, message, null); }

    public static ApiResponse<Void> failure(String code, String message) {
        return new ApiResponse<>(false, null, message, new ApiError(code, null));
    }

    public static ApiResponse<Void> failure(String code, String message, Map<String, String> fields) {
        return new ApiResponse<>(false, null, message, new ApiError(code, fields));
    }

    @JsonInclude(JsonInclude.Include.NON_EMPTY)
    public record ApiError(String code, Map<String, String> fields) {}
}
