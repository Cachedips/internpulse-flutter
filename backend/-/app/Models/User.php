<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'email',
        'password',
        'major',
        'user_skills',
    ];

    protected $hidden = [
        'password',
    ];

    // Kompatibel Laravel 10 maupun 11+
    protected $casts = [
        'user_skills' => 'array',
    ];

    public function trackers()
    {
        return $this->hasMany(ApplicationTracker::class);
    }
}
