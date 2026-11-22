package com.spencerplus.budget.user;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.spencerplus.budget.config.JwtService;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserService userService;
    private final JwtService jwtService;

    public UserController(UserService userService, JwtService jwtService) {
        this.userService = userService;
        this.jwtService = jwtService;
    }

    @PostMapping
    public AuthResponse createUser(@Valid @RequestBody CreateUserRequest request) {
        User user = userService.createUser(
            request.firstName(), request.lastName(), request.email(), request.password(), request.birthday()
        );
        return AuthResponse.of(jwtService.issue(user.getId()), user);
    }

    @GetMapping("/by-email")
    public UserLookupResponse findByEmail(@RequestParam String email) {
        return UserLookupResponse.fromEntity(userService.findByEmail(email));
    }

    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest request) {
        User user = userService.login(request.email(), request.password());
        return AuthResponse.of(jwtService.issue(user.getId()), user);
    }

    public record LoginRequest(@NotBlank String email, @NotBlank String password) {}
}
