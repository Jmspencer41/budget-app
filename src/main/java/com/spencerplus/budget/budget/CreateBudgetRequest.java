package com.spencerplus.budget.budget;

import jakarta.validation.constraints.NotBlank;
import java.util.UUID;

public record CreateBudgetRequest(
    @NotBlank String title,
    UUID ownerId
) {}
