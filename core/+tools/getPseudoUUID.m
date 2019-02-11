function sUUID = getPseudoUUID()
    %GETPSEUDOUUID Generates a random pseudo Universally Unique Identifier (UUID)
    %   Gerenates a string that looks like a UUID but does not follow
    %   RFC4122. A UUID is a 128-bit, practically-unique value. The first
    %   character in the string is always an alphabetic one, this ensures
    %   the UUID can be used as a struct field.
    %
    % NOTE: "Practically unique" is not "guaranteed unique" (see
    %       https://en.wikipedia.org/wiki/UUID). Since the number of
    %       possible UUIDs is |2^128 == 16^32|, one can reasonably expect
    %       the IDs to be unique given a sufficiently high entropy.
    %
    
    % The pool of characters to build the string from, i.e. the
    % usual hexadecimal characters.
    cHexChars = '0123456789ABCDEF';
    
    % In order to be even more sure that the UUIDs we create here are
    % random, we seed the random number generator that MATLAB uses with the
    % current time. 
    rng('shuffle');
    
    % For the first ID character, skip the numeric characters in
    % |cHexChars|, i.e. start with (one-based) index |11 -> 'A'|. Add a
    % random character between current and last index, thus multiply a
    % random number by |16 - 11 == 5|. Pre-allocate the rest of the string
    % with spaces.
    sUUID = [cHexChars(11 + round(rand() * 5)), blanks(31)];

    % For any other character, generate a random number between first and
    % last index of |cHexChars|, i.e. |1 to 16|. Since the indices are
    % one-based, we need to shift the index access to |base.cHexChars| by
    % one.
    for iI = 2:32
        sUUID(iI) = cHexChars(1 + round(rand() * 15));
    end

end

