<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    // POST /api/register  -> {token, user}
    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name'          => 'required|string|max:255',
            'email'         => 'required|email|max:255|unique:users,email',
            'password'      => 'required|string|min:8|confirmed',
            'major'         => 'nullable|string|max:100',
            'user_skills'   => 'nullable|array',
            'user_skills.*' => 'string|max:50',
        ]);

        $user = User::create([
            'name'        => $data['name'],
            'email'       => $data['email'],
            'password'    => Hash::make($data['password']),
            'major'       => $data['major'] ?? null,
            'user_skills' => $data['user_skills'] ?? [],
        ]);

        return response()->json([
            'token' => $user->createToken('mobile')->plainTextToken,
            'user'  => $this->userPayload($user),
        ], 201);
    }

    // POST /api/login  -> {token, user}
    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email'    => 'required|email',
            'password' => 'required|string',
        ]);

        $user = User::where('email', $data['email'])->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['Email atau password salah.'],
            ]);
        }

        return response()->json([
            'token' => $user->createToken('mobile')->plainTextToken,
            'user'  => $this->userPayload($user),
        ]);
    }

    // POST /api/logout
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logout berhasil']);
    }

    // GET /api/me  -> {user}
    public function me(Request $request): JsonResponse
    {
        return response()->json(['user' => $this->userPayload($request->user())]);
    }

    // PUT /api/profile  -> {user}
    public function updateProfile(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name'          => 'sometimes|string|max:255',
            'major'         => 'sometimes|nullable|string|max:100',
            'user_skills'   => 'sometimes|array',
            'user_skills.*' => 'string|max:50',
        ]);

        $user = $request->user();
        $user->update($data);

        return response()->json(['user' => $this->userPayload($user->fresh())]);
    }

    private function userPayload(User $user): array
    {
        return [
            'id'          => $user->id,
            'name'        => $user->name,
            'email'       => $user->email,
            'major'       => $user->major,
            'user_skills' => $user->user_skills ?? [],
        ];
    }
}
