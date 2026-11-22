package com.spencerplus.budget.category;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import com.spencerplus.budget.category.Category.CategoryType;
import com.spencerplus.budget.category.Category.Frequency;

import java.time.LocalDate;
import java.util.UUID;

public record CreateCategoryRequest(
    @NotNull UUID budgetId,
    @NotBlank @Size(max = 100) String name,
    @NotNull CategoryType categoryType,
    Frequency frequency,
    @Positive long amountCents,
    LocalDate anchorDate
) {}