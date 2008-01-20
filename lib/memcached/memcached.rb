
class Memcached

  FLAGS = 0x0

  DEFAULTS = {
    :hash => :default,
    :distribution => :consistent,
    :buffer_requests => false,
    :support_cas => false,
    :tcp_nodelay => false,
    :no_block => false
  }
  
  attr_reader :namespace

  ### Configuration
  
  def initialize(servers, opts = {})
    @struct = Libmemcached::MemcachedSt.new
    Libmemcached.memcached_create(@struct)

    # Servers
    Array(servers).each do |server|
      unless server.is_a? String and server =~ /^(\d{1,3}\.){3}\d{1,3}:\d{1,5}$/
        raise ArgumentError, "Servers must be in the format ip:port (e.g., '127.0.0.1:11211')" 
      end
      host, port = server.split(":")
      Libmemcached.memcached_server_add(@struct, host, port.to_i)

      # XXX To be removed once Krow fixes the write_ptr bug
      Libmemcached.memcached_repair_server_st(@struct, 
        Libmemcached.memcached_select_server_at(@struct, @struct.hosts.count - 1)
      )
    end  
    
    # Behaviors
    (DEFAULTS.merge(opts)).each do |option, value|
    
    end
    
    @namespace = opts[:namespace]
  end
  
  def servers
    servers = []
    @struct.hosts.count.times do |i|
      servers << Libmemcached.memcached_select_server_at(@struct, i)
    end
    servers
  end
    
  ### Operations
  
  public
  
  def set(key, value, timeout=0, marshal=true)
    value = marshal ? Marshal.dump(value) : value.to_s
    check_return_code(
      Libmemcached.memcached_set(@struct, ns(key), value, timeout, FLAGS)
    )
  end
  
  def get(key, marshal=true)
    if key.is_a? Array
      # Multi get
      # XXX Waiting on the real implementation
      key.map do |this_key|
        begin
          get(this_key, marshal)
        rescue NotFound
          # XXX Not sure how this behavior should be defined
        end
      end
    else
      # Single get
      # XXX Server doesn't validate. Possibly a performance problem.
      raise ClientError, "Invalid key" if !key.is_a? String or key =~ /\s/ 
        
      value, flags, return_code = Libmemcached.memcached_get_ruby_string(@struct, ns(key))
      check_return_code(return_code)
      value = Marshal.load(value) if marshal
      value
    end
  end  
  
  public
  
  def delete(key, timeout=0)
    check_return_code(
      Libmemcached.memcached_delete(@struct, ns(key), timeout)
    )  
  end
  
  def add(key, value, timeout=0, marshal=true)
    value = marshal ? Marshal.dump(value) : value.to_s
    check_return_code(
      Libmemcached.memcached_add(@struct, ns(key), value, timeout, FLAGS)
    )
  end
  
  def increment(key, offset=1)
    return_code, value = Libmemcached.memcached_increment(@struct, ns(key), offset)
    check_return_code(return_code)
    value
  end
  
  def decrement(key, offset=1)
    return_code, value = Libmemcached.memcached_decrement(@struct, ns(key), offset)
    check_return_code(return_code)
    value
  end
  
  alias :incr :increment
  alias :decr :decrement
  
  def replace
    raise NotImplemented
  end
  
  def append
    raise NotImplemented
  end
  
  def prepend
    raise NotImplemented
  end
  
  def cas
    raise NotImplemented
  end
  
  def stats
    raise NotImplemented
  end  
  
  ### Operations helpers
  
  private

  def ns(key)
    "#{@namespace}#{key}"
  end
    
  def check_return_code(int)
    return true if int == 0
    raise @@exceptions[int]
  end  
    
end
