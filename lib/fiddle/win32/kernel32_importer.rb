require_relative "../win32"
module Fiddle::Win32::Kernel32Importer
  require_relative "../import"
  require_relative "../types"
  extend Fiddle::Importer
  dlload 'kernel32'
  include Fiddle::Win32Types
end
