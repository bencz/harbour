/*
 * Harbour MT simple test
 *
 * Copyright 2008 Przemyslaw Czerpak <druzus / at / priv.onet.pl>
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
 * As a special exception, the Harbour Project gives permission for
 * additional uses of the text contained in its release of Harbour.
 *
 * The exception is that, if you link the Harbour libraries with other
 * files to produce an executable, this does not by itself cause the
 * resulting executable to be covered by the GNU General Public License.
 * Your use of that executable is in no way restricted on account of
 * linking the Harbour library code into it.
 *
 * This exception does not however invalidate any other reasons why
 * the executable file might be covered by the GNU General Public License.
 *
 * This exception applies only to the code released by the Harbour
 * Project under the name Harbour.  If you copy code from other
 * Harbour Project or Free Software Foundation releases into a copy of
 * Harbour, as the General Public License permits, the exception does
 * not apply to the code that you add in this way.  To avoid misleading
 * anyone as to the status of such modified files, you must delete
 * this exception notice from them.
 *
 * If you write modifications of your own for Harbour, it is your choice
 * whether to permit this exception to apply to your modifications.
 * If you do not wish that, delete this exception notice.
 *
 */

#include "rt_main.ch"

/* Don't change the position of this #include. */
#include "rt_vars.ch"

#define N_THREADS 5
#define N_JOBS    1000
#define N_SUBS    20
#define N_NOTIFY  2000

#ifdef __HARBOUR__
STATIC s_aMTRef
#endif

PROCEDURE Main_MT()

#ifdef __HARBOUR__
   IF hb_mtvm()
      HBTEST DO_MTTES1()              IS "OK"
      HBTEST DO_MTTES2()              IS "3"
      HBTEST DO_MTTES3()              IS "1/123"
      HBTEST DO_MTTES4()              IS "0/.T./1/2"
      HBTEST DO_MTTES5()              IS "2000/2001000"
      HBTEST DO_MTTES6()              IS ".T./ok"
   ENDIF
#endif

   RETURN

#ifdef __HARBOUR__
STATIC FUNCTION DO_MTTES1()

   LOCAL aThreads, aResults, i, nDigit, nSum, nExpected
   LOCAL mtxJobs, mtxResults

   aThreads := {}
   aResults := {}
   mtxJobs := hb_mutexCreate()
   mtxResults := hb_mutexCreate()
   FOR i := 1 TO N_THREADS
      AAdd( aThreads, hb_threadStart( @thFunc(), mtxJobs, mtxResults ) )
   NEXT
   nDigit := 10
   FOR i := 1 TO N_JOBS
      hb_mutexNotify( mtxJobs, nDigit )
      nDigit++
   NEXT
   FOR i := 1 TO N_THREADS
      hb_mutexNotify( mtxJobs, NIL )
   NEXT
   FOR i := 1 TO N_JOBS
      hb_mutexSubscribe( mtxResults,, @nDigit )
      AAdd( aResults, nDigit )
   NEXT
   AEval( aThreads, {| x | hb_threadJoin( x ) } )
   nSum := 0
   FOR EACH nDigit IN aResults
      nSum += nDigit
   NEXT
   nSum := Round( nSum, 2 )
   nExpected := Round( ( 10 + 10 + N_JOBS - 1 ) / 2 / 3 * N_JOBS, 2 )
   IF Round( nSum - nExpected, 2 ) == 0
      RETURN "OK"
   ENDIF

   RETURN "ERROR, final sum: " + hb_ntos( nSum ) + ;
                 " expected: " + hb_ntos( nExpected )

/* __clsSyncSignal() has to wake up all threads waiting in __clsSyncWait() */
STATIC FUNCTION DO_MTTES2()

   LOCAL aThreads := {}, mtxSync, mtxCount, aCount := { 0 }, i, nStart

   mtxSync := hb_mutexCreate()
   mtxCount := hb_mutexCreate()
   FOR i := 1 TO 3
      AAdd( aThreads, hb_threadStart( @thSyncWait(), mtxSync, mtxCount, aCount ) )
   NEXT
   nStart := hb_MilliSeconds()
   DO WHILE hb_MilliSeconds() - nStart < 3000
      __clsSyncSignal( mtxSync )
      hb_mutexLock( mtxCount )
      i := aCount[ 1 ]
      hb_mutexUnlock( mtxCount )
      IF i == 3
         EXIT
      ENDIF
      hb_idleSleep( 0.01 )
   ENDDO
   AEval( aThreads, {| x | hb_threadJoin( x ) } )

   RETURN hb_ntos( aCount[ 1 ] )

STATIC PROCEDURE thSyncWait( mtxSync, mtxCount, aCount )

   /* timeout is in 1/100 of second (Xbase++ compatible) */
   IF __clsSyncWait( mtxSync, 200 )
      hb_mutexLock( mtxCount )
      aCount[ 1 ]++
      hb_mutexUnlock( mtxCount )
   ENDIF

   RETURN

/* local variable passed by reference to new thread cannot be accessed
   on the HVM stack of parent thread after the function returns */
STATIC FUNCTION DO_MTTES3()

   s_aMTRef := { hb_mutexCreate(), NIL }
   TRefStarter()

   RETURN TRefFiller()

STATIC PROCEDURE TRefStarter()

   LOCAL x := 7

   s_aMTRef[ 2 ] := hb_threadStart( @thRefWriter(), s_aMTRef[ 1 ], @x )

   RETURN

STATIC FUNCTION TRefFiller()

   LOCAL a := 1, b := 1, c := 1, d := 1, r

   hb_mutexNotify( s_aMTRef[ 1 ] )
   hb_threadJoin( s_aMTRef[ 2 ], @r )

   RETURN hb_ntos( a * b * c * d ) + "/" + hb_ntos( r )

STATIC FUNCTION thRefWriter( mtx, x )

   hb_mutexSubscribe( mtx )
   x := 123

   RETURN x

/* hb_threadWait() cannot finish before timeout when other thread ends */
STATIC FUNCTION DO_MTTES4()

   LOCAL mtx, thSlow, thFast, nStart, nRes, lTime

   mtx := hb_mutexCreate()
   thSlow := hb_threadStart( @thWaitSlow(), mtx )
   thFast := hb_threadStart( @thWaitFast() )
   nStart := hb_MilliSeconds()
   nRes := hb_threadWait( thSlow, 0.5 )
   lTime := hb_MilliSeconds() - nStart >= 400
   hb_mutexNotify( mtx )

   RETURN hb_ntos( nRes ) + "/" + hb_ValToStr( lTime ) + "/" + ;
          hb_ntos( hb_threadWait( thSlow ) ) + "/" + ;
          hb_ntos( hb_threadWait( { thFast, thSlow },, .T. ) )

STATIC PROCEDURE thWaitSlow( mtx )

   hb_mutexSubscribe( mtx )

   RETURN

STATIC PROCEDURE thWaitFast()

   hb_idleSleep( 0.1 )

   RETURN

/* many threads waiting with short timeout for notifications,
   each notification has to be received exactly once */
STATIC FUNCTION DO_MTTES5()

   LOCAL aThreads := {}, mtx, mtxCount, aCount := { 0, 0 }, i

   mtx := hb_mutexCreate()
   mtxCount := hb_mutexCreate()
   FOR i := 1 TO N_SUBS
      AAdd( aThreads, hb_threadStart( @thSubTimed(), mtx, mtxCount, aCount ) )
   NEXT
   FOR i := 1 TO N_NOTIFY
      hb_mutexNotify( mtx, i )
      IF i % 100 == 0
         hb_idleSleep( 0.002 )
      ENDIF
   NEXT
   FOR i := 1 TO N_SUBS
      hb_mutexNotify( mtx, NIL )
   NEXT
   AEval( aThreads, {| x | hb_threadJoin( x ) } )

   RETURN hb_ntos( aCount[ 1 ] ) + "/" + hb_ntos( aCount[ 2 ] )

STATIC PROCEDURE thSubTimed( mtx, mtxCount, aCount )

   LOCAL xValue

   DO WHILE .T.
      IF hb_mutexSubscribe( mtx, 0.001, @xValue )
         IF xValue == NIL
            EXIT
         ENDIF
         hb_mutexLock( mtxCount )
         aCount[ 1 ]++
         aCount[ 2 ] += xValue
         hb_mutexUnlock( mtxCount )
      ENDIF
   ENDDO

   RETURN

/* hb_threadJoin() has to wait for thread which is waiting for mutex */
STATIC FUNCTION DO_MTTES6()

   LOCAL mtx, th, xResult, lJoin

   mtx := hb_mutexCreate()
   th := hb_threadStart( @thSubResult(), mtx )
   hb_idleSleep( 0.05 )
   hb_threadStart( @thNotifyLater(), mtx )
   lJoin := hb_threadJoin( th, @xResult )

   RETURN hb_ValToStr( lJoin ) + "/" + hb_ValToStr( xResult )

STATIC FUNCTION thSubResult( mtx )

   LOCAL xValue

   hb_mutexSubscribe( mtx,, @xValue )

   RETURN xValue

STATIC PROCEDURE thNotifyLater( mtx )

   hb_idleSleep( 0.1 )
   hb_mutexNotify( mtx, "ok" )

   RETURN

STATIC PROCEDURE thFunc( mtxJobs, mtxResults )

   LOCAL xJob, xResult

   DO WHILE .T.
      hb_mutexSubscribe( mtxJobs,, @xJob )
      IF xJob == NIL
         EXIT
      ENDIF
      xResult := xJob / 3
      hb_mutexNotify( mtxResults, xResult )
   ENDDO

   RETURN

#endif /* __HARBOUR__ */

/* Don't change the position of this #include. */
#include "rt_init.ch"
