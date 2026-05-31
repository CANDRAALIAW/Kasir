<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TransactionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'invoice_number' => $this->invoice_number,
            'user_name' => $this->user->name ?? 'Unknown',
            'branch_name' => $this->branch->name ?? 'Unknown',
            'total' => (float) $this->total,
            'status' => $this->status,
            'payment_method' => $this->payment_method,
            'payment_amount' => (float) $this->payment_amount,
            'change_amount' => (float) $this->change_amount,
            'details' => TransactionDetailResource::collection($this->whenLoaded('details')),
            'created_at' => $this->created_at,
            'formatted_date' => $this->created_at->format('d M Y H:i'),
        ];
    }
}
