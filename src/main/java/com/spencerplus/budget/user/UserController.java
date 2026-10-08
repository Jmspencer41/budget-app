package com.spencerplus.budget.user;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping
    public UserResponse createUser(@Valid @RequestBody CreateUserRequest request) {
        User user = userService.createUser(
            request.firstName(), request.lastName(), request.email(), request.password(), request.birthday()
        );
        return UserResponse.fromEntity(user);
    }

    @GetMapping("/by-email")
    public UserResponse findByEmail(@RequestParam String email) {
        return UserResponse.fromEntity(userService.findByEmail(email));
    }

    @PostMapping("/login")
    public UserResponse login(@Valid @RequestBody LoginRequest request) {
        return UserResponse.fromEntity(userService.login(request.email(), request.password()));
    }

    public record LoginRequest(@NotBlank String email, @NotBlank String password) {}
}
