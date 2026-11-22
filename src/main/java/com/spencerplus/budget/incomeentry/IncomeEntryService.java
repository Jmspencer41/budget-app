package com.spencerplus.budget.incomeentry;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import com.spencerplus.budget.config.AccessService;

@Service
public class IncomeEntryService {
	
	private final IncomeEntryRepository incomeEntryRepository;
	private final AccessService accessService;
	
	public IncomeEntryService(IncomeEntryRepository incomeEntryRepository, AccessService accessService) {
		this.incomeEntryRepository = incomeEntryRepository;
		this.accessService = accessService;
	}
	
	public IncomeEntry createIncomeEntry(UUID incomeSourceId, long amountCents, LocalDate receivedDate) {
		accessService.requireIncomeEditor(incomeSourceId);
		
		IncomeEntry incomeEntry = new IncomeEntry ();
		incomeEntry.setIncomeSourceId(incomeSourceId);
		incomeEntry.setAmountCents(amountCents);
		incomeEntry.setReceivedDate(receivedDate);
		return incomeEntryRepository.save(incomeEntry);
		
	}
	
	public void deleteIncomeEntry(UUID incomeEntryId) {
		IncomeEntry entry = incomeEntryRepository.findById(incomeEntryId)
			.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Income entry not found"));
		accessService.requireIncomeEditor(entry.getIncomeSourceId());
		incomeEntryRepository.deleteById(incomeEntryId);
	}

	public List<IncomeEntry> listForSource(UUID incomeSourceId) {
		accessService.requireIncomeMember(incomeSourceId);
		return incomeEntryRepository.findByIncomeSourceId(incomeSourceId);
	}
	
	public long getTotalCentsBetween(UUID incomeSourceId, LocalDate start, LocalDate end) { // sum of logged entries from start to end, both days included
		List<IncomeEntry> entries = incomeEntryRepository.findByIncomeSourceIdAndReceivedDateBetween(incomeSourceId, start, end);
		long total = 0;
		for (IncomeEntry entry : entries) {
			total += entry.getAmountCents();
		}
		return total;
	}
}
