<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CatBooking extends Model
{
    protected $fillable = [
        'owner_name',
        'owner_phone',
        'cat_name',
        'cat_breed',
        'booking_type',
        'product_id',
        'price',
        'start_date',
        'end_date',
        'status',
        'branch_id',
        'transaction_id',
    ];

    public function product()
    {
        return $this->belongsTo(Product::class);
    }

    public function branch()
    {
        return $this->belongsTo(Branch::class);
    }

    public function transaction()
    {
        return $this->belongsTo(Transaction::class);
    }
}
