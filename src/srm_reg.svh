`ifndef INCLUDED_srm_reg_svh
`define INCLUDED_srm_reg_svh

//--------------------------------------------------------
// CLASS: srm_reg
// Register model
//--------------------------------------------------------
class srm_reg#(type T = int) extends srm_base_reg;
  //------------------
  // Group: Initialization
  //-------------------
  
  // Function: new
  function new(string name, srm_component parent);
    super.new(name, parent);
  endfunction

  //------------------
  // Group: Converter
  //-------------------
  // Function: data_2_bytes
  // Converts the tempate data type into a list of bytes.
  //
  // {byte_n, byte_n_1,......, byte_1, byte_0} = [msb....lsb]
  // Template data type must be byte aligned.
  virtual function srm_data_t data_2_bytes(const ref T data);
    int num_bytes;
    srm_data_t bytes;
    bit [$bits(T)-1:0] datax;

    datax = data;
    num_bytes = $bits(T)/8;
    assert($bits(T) % 8 == 0); // Register must be byte aligned.

    bytes = new[num_bytes];
    for(int i = 0; i < num_bytes; i++) begin
      bytes[i] = (datax >> (i*8)) & 'hff;
    end

    return bytes;
  endfunction

  // Function: bytes_2_data
  // Converts a list of bytes into the template data type.
  //
  // [msb.....lsb] = {byte_n_1,......, byte_1, byte_0}
  virtual function T bytes_2_data(const ref srm_data_t bytes);
    bit [$bits(T)-1:0] datax;
    T data;
    int shift_bits, num_shifted, total_bits;

    num_shifted = 0;
    total_bits = $bits(T);
    datax = 'h0;
    shift_bits = 'h0;

    for(int i = bytes.size() - 1; i >= 0; i--) begin
      datax <<= shift_bits;
      datax |= bytes[i];
      shift_bits = total_bits - num_shifted;
      if(shift_bits > 8) shift_bits = 8;
      num_shifted += shift_bits;
    end

    data = datax;
    return data;
  endfunction

  //------------------
  // Group: Model Access 
  //-------------------
  
  // Function: get
  // Get the value of the register model.
  //
  // Get the bytes from the fields and convert to template data. 
  virtual function T get();
    srm_data_t bytes = get_bytes();
    return bytes_2_data(bytes);
  endfunction

  // Function: set 
  // Set the value of the data in the model.
  // Could do 'const ref' but that prevents passing a literal constant.
  virtual function void set(T data);
    srm_data_t bytes;
    bytes = data_2_bytes(data);
    set_bytes(bytes);
  endfunction
  //------------------
  // Group: Model+Design Access 
  //-------------------
  
  // Task: read
  // Read the data from the design and compare against all non volatile model values.
  //
  // Task will call uvm_error if the field is not volatile and the model value does not
  // match the value read from the design.
  //
  virtual task read(srm_base_handle handle, ref T data);
    srm_data_t bytes, field_bytes;
    srm_byte_enable_t byte_enables;
    int num_bytes;
    srm_base_policy policy;
    bit allow_update;

    num_bytes = $bits(T)/8;
    byte_enables = new[num_bytes];
    bytes = new[num_bytes];

    for(int i = 0; i < num_bytes; i++) byte_enables[i] = 1;

    __read_bytes(handle, bytes, byte_enables);
   
    foreach(_fields[i]) begin
      field_bytes = srm_utils::extract_field(bytes, _fields[i].get_lsb_pos(),
                                                    _fields[i].get_n_bits());
      policy = _fields[i].get_policy(handle.addr_map_name);
      allow_update = policy.read_policy(_fields[i], field_bytes);
      if(allow_update) begin
        _fields[i].set_bytes(field_bytes);
      end
    end

    if(handle.enable_functional_coverage) begin
      post_read();
    end

    // Return data to the user.
    data = bytes_2_data(bytes);
  endtask

  // Task: write
  // Write the data to the design and model.
  //
  // Data is converted to a list of bytes which then updates the 
  // storage inside the model.
  // It is possible to make data as const ref but then I cannot pass 
  // literal constants. 
  virtual task write(srm_base_handle handle, T data);
    srm_data_t bytes, field_bytes;
    srm_byte_enable_t byte_enables;
    srm_base_policy policy;
    bit allow_update;
    int num_bytes;

    num_bytes = $bits(T)/8;

    bytes = data_2_bytes(data);
    byte_enables = new[num_bytes];
    for(int i = 0; i < num_bytes; i++) byte_enables[i] = 1;

    __write_bytes(handle, bytes, byte_enables);
   
    foreach(_fields[i]) begin
      field_bytes = srm_utils::extract_field(bytes, _fields[i].get_lsb_pos(),
                                                    _fields[i].get_n_bits());
      policy = _fields[i].get_policy(handle.addr_map_name);
      allow_update = policy.write_policy(_fields[i], field_bytes);
      if(allow_update) begin
        _fields[i].set_bytes(field_bytes);
      end
    end

    if(handle.enable_functional_coverage) begin
      post_write();
    end

  endtask



endclass

`endif
