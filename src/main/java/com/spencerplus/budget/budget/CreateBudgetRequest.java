package com.spencerplus.budget.budget;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.UUID;

public record CreateBudgetRequest(
    @NotBlank @Size(max = 100) String title,
    @NotNull UUID ownerId
) {}
