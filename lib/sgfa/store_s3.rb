#
# Simple Group of Filing Applications
# Jacket store using AWS S3.
#
# Copyright (C) 2015 by Graham A. Field.
#
# See LICENSE.txt for licensing information.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

require 'aws-sdk'
require 'tempfile'

require_relative 'error'

module Sgfa

#####################################################################
# Stores copies of {History}, {Entry}, and attached files that are
# in a {Jacket} using AWS S3.
#
class StoreS3

  #####################################
  # Open the store
  #
  # @param client [AWS::S3::Client] The configured S3 client
  # @param bucket [String] The bucket name
  # @param prefix [String] Prefix to use for object keys
  def open(client, bucket, prefix=nil)
    @s3 = client
    @bck = bucket
    @pre = prefix || ''
  end # def open()


  #####################################
  # Close the store
  def close()
    true
  end # def close()


  #####################################
  # Get a temp file 
  def temp
    Tempfile.new('blob', Dir.tmpdir, :encoding => 'utf-8')
  end # def temp


  #####################################
  # Get key
  def _key(type, item)
    case type
      when :entry then ext = '-e'
      when :history then ext = '-h'
      when :file then ext = '-f'
      else raise NotImplementedError, 'Invalid item type'
    end
    key = @pre + item + ext
    return key
  end # def _key()
  private :_key


  #####################################
  # Read an item from the store
  def read(type, item)
    key = _key(type, item)
    fi = temp
    fi.set_encoding(Encoding::ASCII_8BIT)
    @s3.read_object( bucket: @bck, key: key, response_target: fi )
    fi.rewind
    return fi
  rescue Aws::S3::Errors::NoSuchKey
    return false  
  end # def read()


  #####################################
  # Store an item
  def write(type, item, cont)
    key = _key(type, item)
    cont.rewind
    @s3.put_object( bucket: @bck, key: key, body: cont )

    if cont.respond_to?( :close! )
      cont.close!
    else
      cont.close
    end
  end # def write()


  #####################################
  # Delete
  def delete(type, item)
    key = _key(type, item)
    @s3.delete_object( bucket: @bck, key: key )
    return true
  rescue Aws::S3::Errors::NoSuchKey
    return false
  end # def delete()


  #####################################
  # Get size of an item
  def size(type, item)
    key = _key(type, item)
    resp = @s3.head_object( bucket: @bck, key: key )
    return resp.content_length
  rescue Aws::S3::Errors::NotFound
    return false
  end # def size()

end # class StoreS3

end # module Sgfa
