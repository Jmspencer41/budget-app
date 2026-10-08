package com.spencerplus.budget.incomeentry;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;

@Service
public class IncomeEntryService {
	
	private final IncomeEntryRepository incomeEntryRepository;
	
	public IncomeEntryService(IncomeEntryRepository incomeEntryRepository) {
		this.incomeEntryRepository = incomeEntryRepository;
	}
	
	public IncomeEntry createIncomeEntry(UUID incomeSourceId, long amountCents, LocalDate receivedDate) {
		
		IncomeEntry incomeEntry = new IncomeEntry ();
		incomeEntry.setIncomeSourceId(incomeSourceId);
		incomeEntry.setAmountCents(amountCents);
		incomeEntry.setReceivedDate(receivedDate);
		return incomeEntryRepository.save(incomeEntry);
		
	}

	public List<IncomeEntry> listForSource(UUID incomeSourceId) {
		return incomeEntryRepository.findByIncomeSourceId(incomeSourceId);
	}
}
