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