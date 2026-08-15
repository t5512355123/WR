/*
 * This program source code file is part of MasterFip project.
 *
 * Copyright (C) 2013-2017 CERN
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, you may find one here:
 * http://www.gnu.org/licenses/old-licenses/gpl-2.0.html
 * or you may search the http://www.gnu.org website for the version 2 license,
 * or you may write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA
 */

/* logger.svh - implementation of test result logging classes */

`ifndef __LOGGER_SVH
 `define __LOGGER_SVH

 `include "serializable.svh"

// converts an array of bytes to a string with given format 
function automatic string array2str(string fmt, uint8_t data[$]);
   string rv ="";
   for(int i =0 ;i<data.size();i++)
     rv = {rv, $sformatf(fmt, data[i]) };
   return rv;
endfunction // str

// represents a single test log:
class UnitTestMessage;

   string m_msg;
   int 	  m_slot;
   
   function new ( int slot, string msg );
      m_msg = msg;
      m_slot = slot;
   endfunction // new

endclass // UnitTestMessage

     

typedef enum
	    {
	     TR_UNKNOWN,
	     TR_FAIL,
	     TR_PASS
	     } TestResult;


// represents a single test log:
class UnitTest;

   // test ID
   int m_id;
   // final result (failure, pass, unknown)
   TestResult m_result;
   // name of the test
   string m_name;
   // detailed reason for the failure
   string  m_failureReason;
   // message buffer
   UnitTestMessage m_messages[$];

   

   function automatic void msg( int slot, string str );
      UnitTestMessage m = new( slot, str );
      m_messages.push_back(m);
   endfunction // msg

   function new ( int id, string name );
      m_id = id;
      m_name = name;
      m_result = TR_UNKNOWN;
   endfunction // new
   
endclass // UnitTest


// class Logger
//
// A singleton class that handles all test result logging activities.
class Logger;
   int m_id;
   
   protected static Logger m_self;
   protected int m_loggerId;
   protected UnitTest m_currentTest;
   protected  UnitTest m_tests[$];
   protected int 	   m_passedTests;
   protected int 	   m_failedTests;
   
       
   
   function new ( string log_file, int id = -1 );
      m_id = 1;
      m_loggerId = id;
      m_currentTest = null;
      m_passedTests = 0;
      m_failedTests = 0;
   endfunction

  // returns the singleton instance 
   static function Logger get();
      if (m_self == null) begin
	 m_self = new( "sim_log.txt" );
      end
      return m_self;
   endfunction // get

   // begins a test
   function automatic void startTest( string name );
      m_currentTest = new( m_id, name );
      m_tests.push_back(m_currentTest);
      $display("[*] Running test %d: %s", m_id, name);
      m_id++;
   endfunction // startTest

   // marks the current test as passed
   function automatic void pass();
      if( m_currentTest.m_result == TR_UNKNOWN)
	begin
	   $display("[*] Test %d PASSED", m_id);
	   m_currentTest.m_result = TR_PASS;
	end
   endfunction // pass
   
   // marks the current test as failed
   function automatic void fail ( string reason );
      $display("[*] Test %d FAILED: %s", m_id, reason);

      m_currentTest.m_result = TR_FAIL;
      m_currentTest.m_failureReason = reason;

   endfunction

   // logs a message within the scope of the current test
   function automatic void msg ( int slot, string m );

      if(m_currentTest)
	m_currentTest.msg(slot, m);
      
      
      $display("  %s", m);

   endfunction // msg

   function automatic int getPassedTestCount();
      automatic int cnt = 0;
      foreach(m_tests[i])
	if (m_tests[i].m_result == TR_PASS)
	  cnt++;
      
      return cnt;
   endfunction // getPassedTestCount
   
   function automatic int getFailedTestCount();
      automatic int cnt = 0;
      foreach(m_tests[i])
	if (m_tests[i].m_result == TR_FAIL)
	  cnt++;
      
      return cnt;
   endfunction // getPassedTestCount
   
   function automatic void fprint(int fd, string str);
      $fdisplay(fd, str);
      $display(str);
   endfunction // fprint

   function automatic string getSystemDate();
      automatic int fd;
      string t;

/*      
      void'($system("date +%X--%x > sys_time.tmp"));
      fd = $fopen("sys_time.tmp","r");
      void'($fscanf(fd,"%s",t));
      $fclose(fd);
      void'($system("rm sys_time.tmp"));
      return t;
 */
      return "00:00:00 1970/01/01";
   endfunction // getSystemDate
	    
   
   function automatic void writeTestReport( string filename );
      automatic int fd = $fopen(filename,"wb");

      fprint(fd, "MasterFIP SV Test Report");
      fprint(fd, $sformatf("Test date: %s\n\n", getSystemDate() ));
      
      
      fprint(fd, "Test Summary ");
      fprint(fd, "-------------");
      
      fprint(fd, $sformatf("%-02d tests PASSED", getPassedTestCount() ) );
      fprint(fd, $sformatf("%-02d tests FAILED", getFailedTestCount() ) );

      fprint(fd, "\nIndividual Test Results:" );
      fprint(fd, "ID  | Test Name                                                                  | Status | Failure Reason" );
      fprint(fd, "----------------------------------------------------------------------------------------------------------" );

      foreach(m_tests[i])
	begin
	   fprint(fd, $sformatf("%-3d | %-74s | %-6s | %s" , m_tests[i].m_id, m_tests[i].m_name, m_tests[i].m_result == TR_PASS ? "PASS" : "FAIL", m_tests[i].m_failureReason ) );

	end

      fprint(fd,"\n\n");
      
      
      foreach(m_tests[i])
	begin
	   automatic UnitTest test = m_tests[i];
	   
	   $fdisplay(fd, "Test messages for test %d", test.m_id );
	   $fdisplay(fd, "---------------------------\n" );

	   foreach(test.m_messages[j])
	     begin
		$fdisplay(fd, test.m_messages[j].m_msg);
	     end
	       
	   $fdisplay(fd, "\n---------------------------\n" );


	end
      
      
   endfunction
   
   
endclass // Logger


class LoggerClient;

     function automatic void startTest( string name );
	automatic Logger l = Logger::get();
	l.startTest( name );
     endfunction // startTest

     function automatic void pass();
	automatic Logger l = Logger::get();
	l.pass();
     endfunction // pass
   
     function automatic void fail ( string reason );
	automatic Logger l = Logger::get();
	l.fail(reason);
     endfunction

   function automatic void msg ( int slot, string m );
	automatic Logger l = Logger::get();
      l.msg(slot, m);
      endfunction // msg

endclass // LoggerClient



`endif //  `ifndef __LOGGER_SVH
