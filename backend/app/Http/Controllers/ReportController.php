<?php

namespace App\Http\Controllers;

use App\Models\Transaction;
use App\Exports\TransactionsExport;
use App\Http\Resources\TransactionResource;
use Illuminate\Http\Request;
use Maatwebsite\Excel\Facades\Excel;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

class ReportController extends Controller
{
    public function incomeStats(Request $request)
    {
        $type = $request->query('type', 'daily'); // daily, monthly, yearly
        $branchId = $request->query('branch_id');
        $date = $request->query('date', Carbon::today()->toDateString());
        $month = $request->query('month', Carbon::today()->format('Y-m'));
        $year = $request->query('year', Carbon::today()->format('Y'));

        $query = Transaction::query();
        if ($branchId) {
            $query->where('branch_id', $branchId);
        }

        switch ($type) {
            case 'daily':
                // Hourly breakdown of selected date
                $stats = $query->select(
                    DB::raw("strftime('%H:00', created_at) as label"),
                    DB::raw('SUM(total) as value')
                )
                ->whereDate('created_at', $date)
                ->groupBy('label')
                ->orderBy('label')
                ->get();
                break;

            case 'monthly':
                // Daily breakdown of selected month (format YYYY-MM)
                $stats = $query->select(
                    DB::raw("strftime('%d', created_at) as label"),
                    DB::raw('SUM(total) as value')
                )
                ->whereYear('created_at', substr($month, 0, 4))
                ->whereMonth('created_at', substr($month, 5, 2))
                ->groupBy('label')
                ->orderBy('label')
                ->get();
                break;

            case 'yearly':
                // Monthly breakdown of selected year (format YYYY)
                $stats = $query->select(
                    DB::raw("strftime('%m', created_at) as label"),
                    DB::raw('SUM(total) as value')
                )
                ->whereYear('created_at', $year)
                ->groupBy('label')
                ->orderBy('label')
                ->get();
                break;

            default:
                $stats = [];
                break;
        }

        return response()->json([
            'status' => 'success',
            'type' => $type,
            'date' => $date,
            'month' => $month,
            'year' => $year,
            'data' => $stats
        ]);
    }

    public function dailyReport(Request $request)
    {
        $type = $request->query('type', 'daily'); // daily, monthly, yearly
        $branchId = $request->query('branch_id');
        $date = $request->query('date', Carbon::today()->toDateString());
        $month = $request->query('month', Carbon::today()->format('Y-m'));
        $year = $request->query('year', Carbon::today()->format('Y'));
        $search = $request->query('search');
        $paymentMethod = $request->query('payment_method');

        $query = Transaction::query();
        if ($branchId) {
            $query->where('branch_id', $branchId);
        }
        if ($search) {
            $query->where(function($q) use ($search) {
                $q->where('invoice_number', 'like', "%{$search}%")
                  ->orWhereHas('user', function($qu) use ($search) {
                      $qu->where('name', 'like', "%{$search}%");
                  });
            });
        }
        if ($paymentMethod && $paymentMethod !== 'semua') {
            $query->where('payment_method', strtolower($paymentMethod));
        }

        if ($type === 'daily') {
            $query->whereDate('created_at', $date);
        } elseif ($type === 'monthly') {
            $query->whereYear('created_at', substr($month, 0, 4))
                  ->whereMonth('created_at', substr($month, 5, 2));
        } elseif ($type === 'yearly') {
            $query->whereYear('created_at', $year);
        }

        $transactions = $query->with(['user', 'details.product', 'branch'])->latest()->get();

        $totalIncome = 0;
        $transactionCount = count($transactions);
        $tunaiTotal = 0;
        $qrisTotal = 0;
        $transferTotal = 0;

        // Group sold products
        $soldSummary = [];

        foreach ($transactions as $tx) {
            $totalIncome += $tx->total;
            if ($tx->payment_method === 'tunai') $tunaiTotal += $tx->total;
            elseif ($tx->payment_method === 'qris') $qrisTotal += $tx->total;
            elseif ($tx->payment_method === 'transfer') $transferTotal += $tx->total;

            foreach ($tx->details as $detail) {
                if (!$detail->product) continue;
                $pId = $detail->product_id;
                if (!isset($soldSummary[$pId])) {
                    $soldSummary[$pId] = [
                        'product_id' => $pId,
                        'name' => $detail->product->name,
                        'qty' => 0,
                        'revenue' => 0,
                        'type' => $detail->product->type ?? 'product'
                    ];
                }
                $soldSummary[$pId]['qty'] += $detail->qty;
                $soldSummary[$pId]['revenue'] += $detail->subtotal;
            }
        }

        // Query incoming products (StockLog in)
        $stockInLogsQuery = \App\Models\StockLog::with(['product', 'user'])->where('type', 'in');
        if ($type === 'daily') {
            $stockInLogsQuery->whereDate('created_at', $date);
        } elseif ($type === 'monthly') {
            $stockInLogsQuery->whereYear('created_at', substr($month, 0, 4))
                             ->whereMonth('created_at', substr($month, 5, 2));
        } elseif ($type === 'yearly') {
            $stockInLogsQuery->whereYear('created_at', $year);
        }
        if ($branchId) {
            $stockInLogsQuery->whereHas('product', function($q) use ($branchId) {
                $q->where('branch_id', $branchId);
            });
        }
        $incomingLogs = $stockInLogsQuery->latest()->get();

        // Group incoming products
        $incomingSummary = [];
        foreach ($incomingLogs as $log) {
            if (!$log->product) continue;
            $pId = $log->product_id;
            if (!isset($incomingSummary[$pId])) {
                $incomingSummary[$pId] = [
                    'product_id' => $pId,
                    'name' => $log->product->name,
                    'qty' => 0,
                ];
            }
            $incomingSummary[$pId]['qty'] += $log->quantity;
        }

        return response()->json([
            'status' => 'success',
            'type' => $type,
            'date' => $date,
            'month' => $month,
            'year' => $year,
            'total_income' => (float) $totalIncome,
            'transaction_count' => (int) $transactionCount,
            'tunai_total' => (float) $tunaiTotal,
            'qris_total' => (float) $qrisTotal,
            'transfer_total' => (float) $transferTotal,
            'sold_summary' => array_values($soldSummary),
            'incoming_summary' => array_values($incomingSummary),
            'incoming_logs' => $incomingLogs,
            'transactions' => TransactionResource::collection($transactions)
        ]);
    }

    public function branchComparison(Request $request)
    {
        $stats = Transaction::select(
            'branches.name as branch_name',
            DB::raw('SUM(total) as revenue'),
            DB::raw('COUNT(*) as total_orders')
        )
        ->join('branches', 'transactions.branch_id', '=', 'branches.id')
        ->where('transactions.created_at', '>=', Carbon::now()->subDays(30))
        ->groupBy('branches.name')
        ->get();

        return response()->json([
            'status' => 'success',
            'data' => $stats
        ]);
    }

    public function exportExcel(Request $request)
    {
        $branchId = $request->query('branch_id');
        $startDate = $request->query('start_date');
        $endDate = $request->query('end_date');
        $fileName = 'Laporan_Penjualan_' . ($branchId ? 'Cabang_'.$branchId.'_' : '') . now()->format('Y-m-d_H-i-s') . '.xlsx';

        return Excel::download(new TransactionsExport($branchId, $startDate, $endDate), $fileName);
    }
}
