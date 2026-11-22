package com.spencerplus.budget.user;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

public record AuthResponse(
    String token,
    UUID id,
    String firstName,
    String lastName,
    String email,
    LocalDate birthday,
    LocalDateTime createdAt
) {
    public static AuthResponse of(String token, User user) {
        return new AuthResponse(
            token,
            user.getId(),
            user.getFirstName(),
            user.getLastName(),
            user.getEmail(),
            user.getBirthday(),
            user.getCreatedAt()
        );
    }
}
