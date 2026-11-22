package com.spencerplus.budget.category;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.LocalDate;
import org.junit.jupiter.api.Test;
import com.spencerplus.budget.category.Category.Frequency;

class CategoryPeriodTest {

    private final CategoryService service = new CategoryService(null, null, null);

    @Test
    void monthlyAnchorOnThe31stClampsToTheMonthEnd() {
        CategoryPeriod february = service.getPeriodContaining(Frequency.MONTHLY, LocalDate.parse("2026-01-31"), LocalDate.parse("2026-02-15"));
        assertEquals(LocalDate.parse("2026-01-31"), february.start());
        assertEquals(LocalDate.parse("2026-02-27"), february.end());
    }

    @Test
    void weeklyPeriodIsSevenDays() {
        CategoryPeriod period = service.getPeriodContaining(Frequency.WEEKLY, LocalDate.parse("2026-11-02"), LocalDate.parse("2026-11-10"));
        assertEquals(LocalDate.parse("2026-11-09"), period.start());
        assertEquals(LocalDate.parse("2026-11-15"), period.end());
    }

    @Test
    void dateBeforeTheAnchorStaysInTheAnchorPeriod() {
        CategoryPeriod period = service.getPeriodContaining(Frequency.MONTHLY, LocalDate.parse("2026-11-01"), LocalDate.parse("2026-10-15"));
        assertEquals(LocalDate.parse("2026-11-01"), period.start());
    }
}
