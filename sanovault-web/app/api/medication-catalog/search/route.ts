import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getCurrentUser } from '@/lib/auth/session';
import { sql } from '@/lib/db/neon';
import { AppError, handleError } from '@/lib/middleware/error-handler';

const countrySchema = z.enum(['IN', 'US', 'GB']);

/**
 * Returns only reviewed, active catalogue products. Pending and flagged products
 * are intentionally never candidates for a patient confirmation.
 */
export async function GET(request: NextRequest) {
  try {
    const user = await getCurrentUser();
    if (!user) throw new AppError('Unauthorized', 401);

    const country = countrySchema.safeParse(request.nextUrl.searchParams.get('country'));
    const query = request.nextUrl.searchParams.get('q')?.trim() || '';
    if (!country.success) throw new AppError('Choose India, USA, or UK before searching', 400);
    if (query.length < 2 || query.length > 100) {
      throw new AppError('Enter between 2 and 100 characters to search the catalogue', 400);
    }

    const products = await sql`
      SELECT
        cp.id, cp.country, cp.brand_name, cp.formulation, cp.source_name, cp.source_version,
        COALESCE(
          jsonb_agg(
            jsonb_build_object(
              'canonicalInn', ci.canonical_inn,
              'localAlias', ci.local_alias,
              'strength', ci.strength,
              'strengthUnit', ci.strength_unit
            ) ORDER BY ci.ingredient_order
          ) FILTER (WHERE ci.id IS NOT NULL),
          '[]'::jsonb
        ) AS ingredients
      FROM medication_catalog_products cp
      LEFT JOIN medication_catalog_product_ingredients ci ON ci.product_id = cp.id
      WHERE cp.country = ${country.data}
        AND cp.review_status = 'VERIFIED'
        AND cp.discontinued = FALSE
        AND cp.normalized_brand_name LIKE ${`%${query.toLowerCase()}%`}
      GROUP BY cp.id
      ORDER BY cp.display_rank ASC, cp.brand_name ASC
      LIMIT 12
    `;

    return NextResponse.json(products.map((product) => ({
      id: String(product.id),
      country: String(product.country),
      brandName: String(product.brand_name),
      formulation: String(product.formulation),
      sourceName: String(product.source_name),
      sourceVersion: String(product.source_version),
      ingredients: Array.isArray(product.ingredients) ? product.ingredients : [],
    })));
  } catch (error) {
    return handleError(error);
  }
}
