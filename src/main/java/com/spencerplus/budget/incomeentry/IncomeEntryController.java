package com.spencerplus.budget.incomeentry;

import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/incomeentries")
public class IncomeEntryController {
	
	private final IncomeEntryService incomeEntryService;
	
	public IncomeEntryController(IncomeEntryService incomeEntryService) {
		this.incomeEntryService = incomeEntryService;
	}
	
	@GetMapping("/source/{incomeSourceId}")
	public List<IncomeEntryResponse> listForSource(@PathVariable UUID incomeSourceId) {
		return incomeEntryService.listForSource(incomeSourceId).stream().map(IncomeEntryResponse::fromEntity).toList();
	}

	@PostMapping
	public IncomeEntryResponse createIncomeEntry(@Valid @RequestBody CreateIncomeEntryRequest request) {
		IncomeEntry incomeEntry = incomeEntryService.createIncomeEntry(
				request.incomeSourceId(), request.amountCents(), request.receivedDate()
				);
		return IncomeEntryResponse.fromEntity(incomeEntry);
	}

}
