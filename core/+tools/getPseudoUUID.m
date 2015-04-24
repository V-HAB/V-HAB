function sUUID = getPseudoUUID()
    %GETPSEUDOUUID Generates a random pseudo UUID starting with [A-F]
    %   Gerenates a string that looks like a UUID but does not follow
    %   RFC4122. A UUID is a 128-bit, practically-unique value. The
    %   first character in the string is always an alphabetic one,
    %   this ensures the UUID can be used as a struct field. 
    %
    %NOTE: Please make sure the PRNG is in a different state each
    %      time the function is called. Otherwise consecutive IDs
    %      will be identical!
    %
    %NOTE: "Practically unique" is not "guaranteed unique" (see 
    %      https://en.wikipedia.org/wiki/UUID). Since the number
    %      of possible UUIDs is |2^128 == 16^32|, one can
    %      reasonably expect the IDs to be unique given a
    %      sufficiently high entropy. 
    %
    %TODO: Drop the first-char-alphabetic constraint and find a
    %      different solution for the ID-as-struct-field problem,
    %      e.g. use |containers.Map()| or add a constant prefix to
    %      the UUID like 'urn2FA26E2...' or 'uuidD513F9B...'.
    %
    %TODO: Make this function RFC-compliant (Type 4) resp.
    %      introduce new functions.
    %
    %TODO: Make sure the PRNG is initialized differently for every
    %      call, i.e. seed the PRNG with pseudo-random data on
    %      every (or the first) call. Or just use a |RandStream|. 

    % The pool of characters to build the string from, i.e. the
    % usual hexadecimal characters.
    cHexChars = '0123456789ABCDEF';
    %iNumHexChars = length(base.cHexChars); % == 16

    % For the first ID character, skip the numeric characters in 
    % |base.cHexChars|, i.e. start with (one-based) index 
    % |11 -> 'a'|. Add a random character between current and last 
    % index, thus multiply a random number by |16 - 11 == 5|.
    % Pre-allocate the rest of the string with spaces.
    sUUID = [cHexChars(11 + round(rand() * 5)), blanks(31)];

    % For any other character, generate a random number between
    % first and last index of |base.cHexChars|, i.e. |1 to 16|. 
    % Since the indices are one-based, we need to shift the index 
    % access to |base.cHexChars| by one.
    for iI = 2:32
        sUUID(iI) = cHexChars(1 + round(rand() * 15));
    end

end

