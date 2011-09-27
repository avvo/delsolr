#
#  Common extensions that we need to define if they don't already exist...
#

String.class_eval do
  if !''.respond_to?(:blank?)    
    def blank?
      self == ''
    end
  end
end

NilClass.class_eval do
  if !nil.respond_to?(:blank?)
    def blank?
      true
    end
  end
end

Hash.class_eval do
  if !{}.respond_to?(:blank?)
    def blank?
      self == {}
    end
  end
end

Fixnum.class_eval do
  if !1.respond_to?(:hours)
    def hours
      self * 60 * 60
    end
  end
end

Array.class_eval do
  if ![].respond_to?(:in_groups_of)
    def in_groups_of(number, fill_with = nil)
      if fill_with == false
        collection = self
      else
        # size % number gives how many extra we have;
        # subtracting from number gives how many to add;
        # modulo number ensures we don't add group of just fill.
        padding = (number - size % number) % number
        collection = dup.concat([fill_with] * padding)
      end
      if block_given?
        collection.each_slice(number) { |slice| yield(slice) }
      else
        returning [] do |groups|
          collection.each_slice(number) { |group| groups << group }
        end
      end
    end
  end
end