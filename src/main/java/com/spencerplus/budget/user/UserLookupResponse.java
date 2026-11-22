package com.spencerplus.budget.user;

import java.util.UUID;

public record UserLookupResponse(UUID id, String firstName, String lastName) {
    public static UserLookupResponse fromEntity(User user) {
        return new UserLookupResponse(user.getId(), user.getFirstName(), user.getLastName());
    }
}
