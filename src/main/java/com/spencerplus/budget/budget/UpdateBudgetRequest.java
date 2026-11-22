package com.spencerplus.budget.budget;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UpdateBudgetRequest(@NotBlank @Size(max = 100) String title) {}
