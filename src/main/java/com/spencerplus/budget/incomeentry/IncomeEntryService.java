package com.spencerplus.budget.incomeentry;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

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
	
	public void deleteIncomeEntry(UUID incomeEntryId) {
	    if (!incomeEntryRepository.existsById(incomeEntryId)) {
	        throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Income entry not found");
	    }
	    incomeEntryRepository.deleteById(incomeEntryId);
	}

	public List<IncomeEntry> listForSource(UUID incomeSourceId) {
		return incomeEntryRepository.findByIncomeSourceId(incomeSourceId);
	}
}
