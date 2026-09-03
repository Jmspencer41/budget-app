package com.spencerplus.budget.user;

import jakarta.validation.constraints.NotBlank;
import java.time.LocalDate;

public record CreateUserRequest(    
		@NotBlank String firstName,
	    @NotBlank String lastName,
	    @NotBlank String email,
	    @NotBlank String password,
	    LocalDate birthday
) {}