/*
 * Regression tests for the runtime library (preprocessor #if expressions
 * with 64-bit integers), included only by Harbour compiler with 64-bit
 * integers support, CA-Cl*pper preprocessor does not support #if
 *
 * Copyright 2026 Alexandre Bencz
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file LICENSE.txt.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA (or visit https://www.gnu.org/licenses/).
 *
 */

#if ( ( -9223372036854775807 - 1 ) % -1 ) == 0 .AND. ( 7 % -1 ) == 0 .AND. ( -7 % 3 ) == -1
      HBTEST "PP %"                                              IS "PP %"
#else
      HBTEST "PP %"                                              IS "PP % failed"
#endif
#if ( ( -9223372036854775807 - 1 ) / -1 ) < 0 .AND. ( 7 / -1 ) == -7 .AND. ( -7 / -1 ) == 7
      HBTEST "PP /"                                              IS "PP /"
#else
      HBTEST "PP /"                                              IS "PP / failed"
#endif
