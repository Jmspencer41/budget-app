package com.spencerplus.budget.user;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

public record CreateUserRequest(    
		@NotBlank @Size(max = 100) String firstName,
	    @NotBlank @Size(max = 100) String lastName,
	    @NotBlank @Size(max = 255) String email,
	    @NotBlank @Size(max = 100) String password,
	    LocalDate birthday
) {}