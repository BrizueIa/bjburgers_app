import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/sync/sync_queue_service.dart';

class CashSessionSummary {
  const CashSessionSummary({
    required this.id,
    required this.status,
    required this.openedAt,
    required this.openingAmount,
    required this.closedAt,
    required this.closingExpectedCash,
    required this.closingRealCash,
    required this.transferTotal,
    required this.differenceAmount,
    required this.note,
    required this.cashSalesTotal,
    required this.transferSalesTotal,
    required this.manualDeposits,
    required this.manualWithdrawals,
    required this.manualAdjustments,
  });

  final String id;
  final String status;
  final DateTime openedAt;
  final double openingAmount;
  final DateTime? closedAt;
  final double? closingExpectedCash;
  final double? closingRealCash;
  final double transferTotal;
  final double? differenceAmount;
  final String? note;
  final double cashSalesTotal;
  final double transferSalesTotal;
  final double manualDeposits;
  final double manualWithdrawals;
  final double manualAdjustments;

  bool get isOpen => status == 'open';

  double get expectedCash =>
      openingAmount +
      cashSalesTotal +
      manualDeposits +
      manualAdjustments -
      manualWithdrawals;
}

class CashMovementSummary {
  const CashMovementSummary({
    required this.id,
    required this.cashSessionId,
    required this.movementType,
    required this.paymentMethod,
    required this.amount,
    required this.note,
    required this.referenceType,
    required this.referenceId,
    required this.createdAt,
  });

  final String id;
  final String cashSessionId;
  final String movementType;
  final String? paymentMethod;
  final double amount;
  final String? note;
  final String? referenceType;
  final String? referenceId;
  final DateTime createdAt;
}

class CajaRepository {
  CajaRepository(this._database, this._syncQueueService);

  final AppDatabase _database;
  final SyncQueueService _syncQueueService;
  final Uuid _uuid = const Uuid();

  Stream<CashSessionSummary?> watchActiveSession() {
    const sql = '''
      SELECT
        cs.id,
        cs.status,
        cs.opened_at,
        cs.opening_amount,
        cs.closed_at,
        cs.closing_expected_cash,
        cs.closing_real_cash,
        cs.transfer_total,
        cs.difference_amount,
        cs.note,
        COALESCE(SUM(CASE WHEN cm.movement_type = 'sale' AND cm.payment_method = 'cash' THEN cm.amount ELSE 0 END), 0) AS cash_sales_total,
        COALESCE(SUM(CASE WHEN cm.movement_type = 'sale' AND cm.payment_method = 'transfer' THEN cm.amount ELSE 0 END), 0) AS transfer_sales_total,
        COALESCE(SUM(CASE WHEN cm.movement_type = 'deposit' THEN cm.amount ELSE 0 END), 0) AS manual_deposits,
        COALESCE(SUM(CASE WHEN cm.movement_type = 'withdrawal' THEN cm.amount ELSE 0 END), 0) AS manual_withdrawals,
        COALESCE(SUM(CASE WHEN cm.movement_type = 'adjustment' THEN cm.amount ELSE 0 END), 0) AS manual_adjustments
      FROM cash_sessions cs
      LEFT JOIN cash_movements cm ON cm.cash_session_id = cs.id
      WHERE cs.status = 'open'
      GROUP BY cs.id
      ORDER BY cs.opened_at DESC
      LIMIT 1
    ''';

    return _database
        .customSelect(
          sql,
          readsFrom: {_database.cashSessions, _database.cashMovements},
        )
        .watch()
        .map((rows) {
          if (rows.isEmpty) return null;
          final row = rows.first;
          return CashSessionSummary(
            id: row.read<String>('id'),
            status: row.read<String>('status'),
            openedAt: row.read<DateTime>('opened_at'),
            openingAmount: row.read<double>('opening_amount'),
            closedAt: row.read<DateTime?>('closed_at'),
            closingExpectedCash: row.read<double?>('closing_expected_cash'),
            closingRealCash: row.read<double?>('closing_real_cash'),
            transferTotal: row.read<double>('transfer_total'),
            differenceAmount: row.read<double?>('difference_amount'),
            note: row.read<String?>('note'),
            cashSalesTotal: row.read<double>('cash_sales_total'),
            transferSalesTotal: row.read<double>('transfer_sales_total'),
            manualDeposits: row.read<double>('manual_deposits'),
            manualWithdrawals: row.read<double>('manual_withdrawals'),
            manualAdjustments: row.read<double>('manual_adjustments'),
          );
        });
  }

  Stream<List<CashSessionSummary>> watchSessions() {
    const sql = '''
      SELECT
        cs.id,
        cs.status,
        cs.opened_at,
        cs.opening_amount,
        cs.closed_at,
        cs.closing_expected_cash,
        cs.closing_real_cash,
        cs.transfer_total,
        cs.difference_amount,
        cs.note,
        COALESCE(SUM(CASE WHEN cm.movement_type = 'sale' AND cm.payment_method = 'cash' THEN cm.amount ELSE 0 END), 0) AS cash_sales_total,
        COALESCE(SUM(CASE WHEN cm.movement_type = 'sale' AND cm.payment_method = 'transfer' THEN cm.amount ELSE 0 END), 0) AS transfer_sales_total,
        COALESCE(SUM(CASE WHEN cm.movement_type = 'deposit' THEN cm.amount ELSE 0 END), 0) AS manual_deposits,
        COALESCE(SUM(CASE WHEN cm.movement_type = 'withdrawal' THEN cm.amount ELSE 0 END), 0) AS manual_withdrawals,
        COALESCE(SUM(CASE WHEN cm.movement_type = 'adjustment' THEN cm.amount ELSE 0 END), 0) AS manual_adjustments
      FROM cash_sessions cs
      LEFT JOIN cash_movements cm ON cm.cash_session_id = cs.id
      GROUP BY cs.id
      ORDER BY cs.opened_at DESC
    ''';

    return _database
        .customSelect(
          sql,
          readsFrom: {_database.cashSessions, _database.cashMovements},
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => CashSessionSummary(
                  id: row.read<String>('id'),
                  status: row.read<String>('status'),
                  openedAt: row.read<DateTime>('opened_at'),
                  openingAmount: row.read<double>('opening_amount'),
                  closedAt: row.read<DateTime?>('closed_at'),
                  closingExpectedCash: row.read<double?>(
                    'closing_expected_cash',
                  ),
                  closingRealCash: row.read<double?>('closing_real_cash'),
                  transferTotal: row.read<double>('transfer_total'),
                  differenceAmount: row.read<double?>('difference_amount'),
                  note: row.read<String?>('note'),
                  cashSalesTotal: row.read<double>('cash_sales_total'),
                  transferSalesTotal: row.read<double>('transfer_sales_total'),
                  manualDeposits: row.read<double>('manual_deposits'),
                  manualWithdrawals: row.read<double>('manual_withdrawals'),
                  manualAdjustments: row.read<double>('manual_adjustments'),
                ),
              )
              .toList(),
        );
  }

  Stream<List<CashMovementSummary>> watchMovements(String sessionId) {
    final query = _database.select(_database.cashMovements)
      ..where((table) => table.cashSessionId.equals(sessionId))
      ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => CashMovementSummary(
              id: row.id,
              cashSessionId: row.cashSessionId,
              movementType: row.movementType,
              paymentMethod: row.paymentMethod,
              amount: row.amount,
              note: row.note,
              referenceType: row.referenceType,
              referenceId: row.referenceId,
              createdAt: row.createdAt,
            ),
          )
          .toList(),
    );
  }

  Future<void> openSession({
    required double openingAmount,
    String? note,
  }) async {
    final active = await fetchActiveSession();
    if (active != null) {
      throw StateError('Ya existe una caja abierta.');
    }

    final now = DateTime.now();
    final sessionId = _uuid.v4();
    final movementId = _uuid.v4();
    await _database.transaction(() async {
      await _database
          .into(_database.cashSessions)
          .insert(
            CashSessionsCompanion.insert(
              id: sessionId,
              openedAt: now,
              openingAmount: Value(openingAmount),
              note: Value(note?.isEmpty ?? true ? null : note),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _database
          .into(_database.cashMovements)
          .insert(
            CashMovementsCompanion.insert(
              id: movementId,
              cashSessionId: sessionId,
              movementType: 'opening',
              paymentMethod: const Value('cash'),
              amount: Value(openingAmount),
              note: Value(note?.isEmpty ?? true ? null : note),
              referenceType: const Value('cash_session'),
              referenceId: Value(sessionId),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    await _syncQueueService.enqueue(
      entityType: 'cash_sessions',
      entityId: sessionId,
      operationType: 'upsert',
      payload: {
        'id': sessionId,
        'opened_at': now.toUtc().toIso8601String(),
        'opening_amount': openingAmount,
        'closed_at': null,
        'closing_expected_cash': null,
        'closing_real_cash': null,
        'transfer_total': 0,
        'difference_amount': null,
        'status': 'open',
        'note': note?.isEmpty ?? true ? null : note,
        'created_at': now.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
      },
    );
    await _syncQueueService.enqueue(
      entityType: 'cash_movements',
      entityId: movementId,
      operationType: 'upsert',
      payload: {
        'id': movementId,
        'cash_session_id': sessionId,
        'movement_type': 'opening',
        'payment_method': 'cash',
        'amount': openingAmount,
        'note': note?.isEmpty ?? true ? null : note,
        'reference_type': 'cash_session',
        'reference_id': sessionId,
        'created_at': now.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> addManualMovement({
    required String movementType,
    required double amount,
    required String paymentMethod,
    String? note,
  }) async {
    final active = await fetchActiveSession();
    if (active == null) {
      throw StateError('No hay una caja abierta.');
    }

    final now = DateTime.now();
    final movementId = _uuid.v4();
    await _database.transaction(() async {
      await _database
          .into(_database.cashMovements)
          .insert(
            CashMovementsCompanion.insert(
              id: movementId,
              cashSessionId: active.id,
              movementType: movementType,
              paymentMethod: Value(paymentMethod),
              amount: Value(amount),
              note: Value(note?.isEmpty ?? true ? null : note),
              createdAt: now,
              updatedAt: now,
            ),
          );

      if (paymentMethod == 'transfer') {
        await (_database.update(
          _database.cashSessions,
        )..where((table) => table.id.equals(active.id))).write(
          CashSessionsCompanion(
            transferTotal: Value(active.transferTotal + amount),
            updatedAt: Value(now),
          ),
        );
      } else {
        await (_database.update(_database.cashSessions)
              ..where((table) => table.id.equals(active.id)))
            .write(CashSessionsCompanion(updatedAt: Value(now)));
      }
    });

    final session = await (_database.select(
      _database.cashSessions,
    )..where((table) => table.id.equals(active.id))).getSingle();
    await _syncQueueService.enqueue(
      entityType: 'cash_movements',
      entityId: movementId,
      operationType: 'upsert',
      payload: {
        'id': movementId,
        'cash_session_id': active.id,
        'movement_type': movementType,
        'payment_method': paymentMethod,
        'amount': amount,
        'note': note?.isEmpty ?? true ? null : note,
        'reference_type': null,
        'reference_id': null,
        'created_at': now.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
      },
    );
    await _syncQueueService.enqueue(
      entityType: 'cash_sessions',
      entityId: session.id,
      operationType: 'upsert',
      payload: {
        'id': session.id,
        'opened_at': session.openedAt.toUtc().toIso8601String(),
        'opening_amount': session.openingAmount,
        'closed_at': session.closedAt?.toUtc().toIso8601String(),
        'closing_expected_cash': session.closingExpectedCash,
        'closing_real_cash': session.closingRealCash,
        'transfer_total': session.transferTotal,
        'difference_amount': session.differenceAmount,
        'status': session.status,
        'note': session.note,
        'created_at': session.createdAt.toUtc().toIso8601String(),
        'updated_at': session.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> recordSaleMovement({
    required String paymentMethod,
    required double amount,
    required String saleId,
  }) async {
    final active = await fetchActiveSession();
    if (active == null) return;

    final now = DateTime.now();
    final movementId = _uuid.v4();
    await _database.transaction(() async {
      await _database
          .into(_database.cashMovements)
          .insert(
            CashMovementsCompanion.insert(
              id: movementId,
              cashSessionId: active.id,
              movementType: 'sale',
              paymentMethod: Value(paymentMethod),
              amount: Value(amount),
              referenceType: const Value('sale'),
              referenceId: Value(saleId),
              createdAt: now,
              updatedAt: now,
            ),
          );

      if (paymentMethod == 'transfer') {
        await (_database.update(
          _database.cashSessions,
        )..where((table) => table.id.equals(active.id))).write(
          CashSessionsCompanion(
            transferTotal: Value(active.transferTotal + amount),
            updatedAt: Value(now),
          ),
        );
      } else {
        await (_database.update(_database.cashSessions)
              ..where((table) => table.id.equals(active.id)))
            .write(CashSessionsCompanion(updatedAt: Value(now)));
      }
    });

    final session = await (_database.select(
      _database.cashSessions,
    )..where((table) => table.id.equals(active.id))).getSingle();
    await _syncQueueService.enqueue(
      entityType: 'cash_movements',
      entityId: movementId,
      operationType: 'upsert',
      payload: {
        'id': movementId,
        'cash_session_id': active.id,
        'movement_type': 'sale',
        'payment_method': paymentMethod,
        'amount': amount,
        'note': null,
        'reference_type': 'sale',
        'reference_id': saleId,
        'created_at': now.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
      },
    );
    await _syncQueueService.enqueue(
      entityType: 'cash_sessions',
      entityId: session.id,
      operationType: 'upsert',
      payload: {
        'id': session.id,
        'opened_at': session.openedAt.toUtc().toIso8601String(),
        'opening_amount': session.openingAmount,
        'closed_at': session.closedAt?.toUtc().toIso8601String(),
        'closing_expected_cash': session.closingExpectedCash,
        'closing_real_cash': session.closingRealCash,
        'transfer_total': session.transferTotal,
        'difference_amount': session.differenceAmount,
        'status': session.status,
        'note': session.note,
        'created_at': session.createdAt.toUtc().toIso8601String(),
        'updated_at': session.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> closeSession({required double realCash, String? note}) async {
    final active = await fetchActiveSession();
    if (active == null) {
      throw StateError('No hay una caja abierta.');
    }

    final expectedCash = active.expectedCash;
    final difference = realCash - expectedCash;
    final now = DateTime.now();
    final movementId = _uuid.v4();

    await _database.transaction(() async {
      await (_database.update(
        _database.cashSessions,
      )..where((table) => table.id.equals(active.id))).write(
        CashSessionsCompanion(
          status: const Value('closed'),
          closedAt: Value(now),
          closingExpectedCash: Value(expectedCash),
          closingRealCash: Value(realCash),
          differenceAmount: Value(difference),
          note: Value(note?.isEmpty ?? true ? active.note : note),
          updatedAt: Value(now),
        ),
      );

      await _database
          .into(_database.cashMovements)
          .insert(
            CashMovementsCompanion.insert(
              id: movementId,
              cashSessionId: active.id,
              movementType: 'closing',
              paymentMethod: const Value('cash'),
              amount: Value(realCash),
              note: Value(note?.isEmpty ?? true ? null : note),
              referenceType: const Value('cash_session'),
              referenceId: Value(active.id),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    await _syncQueueService.enqueue(
      entityType: 'cash_sessions',
      entityId: active.id,
      operationType: 'upsert',
      payload: {
        'id': active.id,
        'opened_at': active.openedAt.toUtc().toIso8601String(),
        'opening_amount': active.openingAmount,
        'closed_at': now.toUtc().toIso8601String(),
        'closing_expected_cash': expectedCash,
        'closing_real_cash': realCash,
        'transfer_total': active.transferTotal,
        'difference_amount': difference,
        'status': 'closed',
        'note': note?.isEmpty ?? true ? active.note : note,
        'created_at': active.openedAt.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
      },
    );
    await _syncQueueService.enqueue(
      entityType: 'cash_movements',
      entityId: movementId,
      operationType: 'upsert',
      payload: {
        'id': movementId,
        'cash_session_id': active.id,
        'movement_type': 'closing',
        'payment_method': 'cash',
        'amount': realCash,
        'note': note?.isEmpty ?? true ? null : note,
        'reference_type': 'cash_session',
        'reference_id': active.id,
        'created_at': now.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
      },
    );
  }

  Future<CashSessionSummary?> fetchActiveSession() async {
    return await watchActiveSession().first;
  }
}

final cajaRepositoryProvider = Provider<CajaRepository>((ref) {
  return CajaRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(syncQueueServiceProvider),
  );
});
