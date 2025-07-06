// Reusable widget for displaying health records in lists and grids

import 'package:flutter/material.dart';
import '../models/health_record.dart';

class HealthRecordCard extends StatelessWidget {
  final HealthRecord record;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const HealthRecordCard({
    required this.record,
    this.onTap,
    this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      record.recordType,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: onDelete,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                record.source,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${record.createdAt.day}/${record.createdAt.month}/${record.createdAt.year}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (record.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: record.tags
                      .take(3)
                      .map((tag) => Chip(
                            label: Text(tag),
                            labelStyle: const TextStyle(fontSize: 12),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 