package com.spencerplus.budget.incomesource;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.Test;
import com.spencerplus.budget.incomesource.IncomeSource.Frequency;

class IncomeSourcePayDatesTest {

	private final IncomeSourceService service = new IncomeSourceService(null, null); // pay date math never touches the database

	private IncomeSource source(Frequency frequency, long amountCents, String anchorDate, Integer secondPayDay) {
		IncomeSource incomeSource = new IncomeSource();
		incomeSource.setFrequency(frequency);
		incomeSource.setAmountCents(amountCents);
		incomeSource.setAnchorDate(LocalDate.parse(anchorDate));
		incomeSource.setSecondPayDay(secondPayDay);
		return incomeSource;
	}

	private LocalDate date(String text) {
		return LocalDate.parse(text);
	}

	@Test
	void biweeklyNovemberHasTwoPaychecks() {
		IncomeSource paycheck = source(Frequency.BIWEEKLY, 200000, "2026-10-24", null);
		assertEquals(List.of(date("2026-11-07"), date("2026-11-21")), service.getPayDates(paycheck, date("2026-11-01"), date("2026-11-30")));
		assertEquals(400000, service.getExpectedCents(paycheck, date("2026-11-04")));
	}

	@Test
	void biweeklyJanuaryHasThreePaychecks() {
		IncomeSource paycheck = source(Frequency.BIWEEKLY, 200000, "2026-10-24", null);
		assertEquals(List.of(date("2027-01-02"), date("2027-01-16"), date("2027-01-30")), service.getPayDates(paycheck, date("2027-01-01"), date("2027-01-31")));
		assertEquals(600000, service.getExpectedCents(paycheck, date("2027-01-10")));
	}

	@Test
	void receivedStepsUpOnPaydays() {
		IncomeSource paycheck = source(Frequency.BIWEEKLY, 200000, "2026-10-24", null);
		assertEquals(0, service.getReceivedCents(paycheck, date("2026-11-06")));      // day before payday
		assertEquals(200000, service.getReceivedCents(paycheck, date("2026-11-07"))); // payday itself counts
		assertEquals(200000, service.getReceivedCents(paycheck, date("2026-11-20")));
		assertEquals(400000, service.getReceivedCents(paycheck, date("2026-11-21")));
	}

	@Test
	void monthlyAnchorOn31stClampsInFebruary() {
		IncomeSource paycheck = source(Frequency.MONTHLY, 300000, "2027-01-31", null);
		assertEquals(List.of(date("2027-02-28")), service.getPayDates(paycheck, date("2027-02-01"), date("2027-02-28")));
		assertEquals(List.of(date("2027-03-31")), service.getPayDates(paycheck, date("2027-03-01"), date("2027-03-31"))); // back to the 31st, no drift
	}

	@Test
	void semimonthly31stInThirtyDayMonth() {
		IncomeSource paycheck = source(Frequency.SEMIMONTHLY, 200000, "2026-10-15", 31);
		assertEquals(List.of(date("2026-11-15"), date("2026-11-30")), service.getPayDates(paycheck, date("2026-11-01"), date("2026-11-30")));
	}

	@Test
	void semimonthlySkipsDatesBeforeAnchor() {
		IncomeSource paycheck = source(Frequency.SEMIMONTHLY, 200000, "2026-10-15", 1);
		assertEquals(List.of(date("2026-10-15")), service.getPayDates(paycheck, date("2026-10-01"), date("2026-10-31"))); // Oct 1 is before the anchor
	}

	@Test
	void futureAnchorHasNothingReceived() {
		IncomeSource paycheck = source(Frequency.BIWEEKLY, 200000, "2026-12-04", null);
		assertEquals(0, service.getReceivedCents(paycheck, date("2026-11-30")));
		assertEquals(date("2026-12-04"), service.getNextPayDate(paycheck, date("2026-11-04")));
	}

	@Test
	void todaysNumbersForTheTestData() { // matches the table from Phase 2, with today as Nov 4 2026
		LocalDate today = date("2026-11-04");

		IncomeSource biweekly = source(Frequency.BIWEEKLY, 200000, "2026-10-24", null);
		assertEquals(0, service.getReceivedCents(biweekly, today));
		assertEquals(400000, service.getExpectedCents(biweekly, today));
		assertEquals(date("2026-11-07"), service.getNextPayDate(biweekly, today));

		IncomeSource semi = source(Frequency.SEMIMONTHLY, 200000, "2026-10-01", 15);
		assertEquals(200000, service.getReceivedCents(semi, today));
		assertEquals(400000, service.getExpectedCents(semi, today));
		assertEquals(date("2026-11-15"), service.getNextPayDate(semi, today));

		IncomeSource monthly = source(Frequency.MONTHLY, 300000, "2026-10-01", null);
		assertEquals(300000, service.getReceivedCents(monthly, today));
		assertEquals(300000, service.getExpectedCents(monthly, today));
		assertEquals(date("2026-12-01"), service.getNextPayDate(monthly, today));
	}
}