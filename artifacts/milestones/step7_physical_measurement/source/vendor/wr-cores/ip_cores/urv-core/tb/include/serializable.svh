`ifndef __SERIALIZABLE_SVH
 `define __SERIALIZABLE_SVH

`include "simdrv_defs.svh"

typedef byte int8_t;
typedef byte unsigned uint8_t;

typedef uint8_t uint8_array_t[$];

class ByteBuffer;
   
   uint8_t data[$];
   int 	pos;

   function  new();
      pos = 0;
   endfunction // new

   function ByteBuffer copy();
    copy = new();
    copy.pos = this.pos;
    copy.data = this.data;
    return copy;
   endfunction // copy

   task automatic clear();
      data = '{};
      pos = 0;
   endtask
   
   task dump();
      int i;

      $display("buffer has %d bytes", data.size());
      
      for (i=0;i<data.size();i++)
	$display("%d: %x", i, data[i]);
      
   endtask // dump
   
	
   
      
   function int size();
      return data.size();
   endfunction // size

   function int getPos();
      return pos;
   endfunction // getPos

   function automatic void setPos( int pos_ );
      pos = pos_;
   endfunction // setPos
   
   
   
   function automatic void addByte ( uint8_t c );
      data.push_back(c);
   endfunction // addByte
   
   function automatic void addShort ( uint32_t c );
      data.push_back((c >> 8) & 'hff);
      data.push_back(c & 'hff);
   endfunction // addShort
   
   function automatic void addWord ( uint32_t c );
      data.push_back((c >> 24) & 'hff);
      data.push_back((c >> 16) & 'hff);
      data.push_back((c >> 8) & 'hff);
      data.push_back(c & 'hff);
   endfunction // addWord

   function automatic void addBytes ( uint8_t d[$] );
      for (int i=0;i<d.size();i++)
	data.push_back(d[i]);
   endfunction // addBytes
   

   function automatic uint8_t getByte();
      automatic uint8_t rv = data[pos++];
      return rv;
   endfunction // getByte

   function automatic uint8_t at(int pos_);
      return data[pos_];
   endfunction
   
   function automatic uint8_array_t getBytes(int count);
      automatic uint8_array_t rv;
      
      for (int i=0;i<count;i++)
	rv.push_back(data[pos++]);

      return rv;
   endfunction // getBytes
   
   
   function automatic uint32_t getWord();
      automatic uint32_t rv;
      rv = data[pos++];
      rv <<= 8;
      rv |= data[pos++];
      rv <<= 8;
      rv |= data[pos++];
      rv <<= 8;
      rv |= data[pos++];

      return rv;
   endfunction // getWord

   function automatic void reset();
      pos = 0;
   endfunction
 // reset
   
   
endclass // ByteBuffer
   
class Serializable;

   protected ByteBuffer m_data;
 
  virtual function automatic void serialize( ByteBuffer data );
  endfunction // serialize
   
  virtual function automatic void deserialize ( ByteBuffer data );
     m_data = data;
  endfunction // deserialize

   virtual task automatic dump();
      if(!m_data)
	return;

      m_data.dump();
      
   endtask // dump
   
   
  function automatic void deserializeBytes ( uint8_t data[$]);
     automatic ByteBuffer b = new ;
     b.data = data;
     deserialize( b );
  endfunction // deserializeBytes
   
   
endclass // Serializable


`endif //  `ifndef __SERIALIZABLE_SVH

