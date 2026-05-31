<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Product extends Model
{
    use SoftDeletes;

    protected $fillable = ['name', 'description', 'price', 'stock', 'image_path', 'branch_id', 'minimum_stock', 'type'];

    public function branch()
    {
        return $this->belongsTo(Branch::class);
    }

    public function stockLogs()
    {
        return $this->hasMany(StockLog::class);
    }
}
