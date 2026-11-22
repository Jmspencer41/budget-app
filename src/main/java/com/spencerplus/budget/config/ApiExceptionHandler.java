package com.spencerplus.budget.config;

import java.util.Map;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class ApiExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, String>> invalid(MethodArgumentNotValidException exception) {
        String message = "Check the values you sent";
        if (exception.getBindingResult().getFieldError() != null) {
            message = exception.getBindingResult().getFieldError().getDefaultMessage();
        }
        return ResponseEntity.badRequest().body(Map.of("message", message));
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<Map<String, String>> conflict(DataIntegrityViolationException exception) {
        return ResponseEntity.status(HttpStatus.CONFLICT)
            .body(Map.of("message", "That conflicts with data already saved"));
    }
}
