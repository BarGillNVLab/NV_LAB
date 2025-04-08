        function encodedSequence = en2(pulse)
            % Convert the sequence into the binary format required.
            % Native java is used for efficient base64 encoding.
            
            % check for a valid pulse
            if isempty(pulse.ticks)
                encodedSequence = [];
                warning('Empty pulse / pulse of length == 0 found.');
                return;
            end
                       
            error(javachk('jvm'));
            
            %split into pulses of with a maximum duration of 2s
            ticksRemaining = pulse.ticks;
            ticksPulse = ones(1, floor((ticksRemaining-1)/2000000) + 1 ) * 2000000;
            ticksPulse(end) = mod(ticksRemaining, 2000000 + 1);

            n_pulses = length(ticksPulse);
            bufferSize = n_pulses*9;
            
            byteBuffer = java.nio.ByteBuffer.allocate(bufferSize);
            for i = 1:n_pulses
                t = uint32(ticksPulse(i));
                digi = pulse.digital;
                ao0 = pulse.analog0;
                ao1 = pulse.analog1;
                byteBuffer.putInt(t);
                byteBuffer.put(java.lang.Byte(digi).byteValue());
                byteBuffer.putShort(ao0);
                byteBuffer.putShort(ao1);                
            end
            encodedSequence = transpose(char(org.apache.commons.codec.binary.Base64.encodeBase64(byteBuffer.array(), 0)));
        end
            