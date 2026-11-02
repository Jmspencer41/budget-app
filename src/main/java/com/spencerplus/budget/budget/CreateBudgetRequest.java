package com.spencerplus.budget.budget;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record CreateBudgetRequest(
    @NotBlank String title,
    @NotNull UUID ownerId
) {}
