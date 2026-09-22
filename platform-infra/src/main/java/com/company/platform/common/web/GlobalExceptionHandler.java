package com.company.platform.common.web;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public Map<String,Object> validation(MethodArgumentNotValidException ex) {
        return Map.of("success", false, "status", 400, "message", "Validation failed");
    }

    @ExceptionHandler(Exception.class)
    public Map<String,Object> generic(Exception ex) {
        return Map.of("success", false, "status", HttpStatus.INTERNAL_SERVER_ERROR.value(),
                "message", "Internal server error");
    }
}
