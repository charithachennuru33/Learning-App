package com.company.platform.common.web;

import jakarta.validation.ConstraintViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public Map<String, Object> handleValidation(MethodArgumentNotValidException ex) {
        return Map.of(
                "success", false,
                "status", HttpStatus.BAD_REQUEST.value(),
                "message", "Validation failed"
        );
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public Map<String, Object> handleConstraintViolation(ConstraintViolationException ex) {
        return Map.of(
                "success", false,
                "status", HttpStatus.BAD_REQUEST.value(),
                "message", "Validation failed"
        );
    }

    @ExceptionHandler(Exception.class)
    public Map<String, Object> handleGeneric(Exception ex) {
        return Map.of(
                "success", false,
                "status", HttpStatus.INTERNAL_SERVER_ERROR.value(),
                "message", "Internal server error"
        );
    }
}
