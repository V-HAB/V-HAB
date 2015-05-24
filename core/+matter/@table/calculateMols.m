function fAmount = calculateMols(this, varargin) % afMasses)
    %CALCULATEMOLS Calculates the amount of matter in mols
    %   Calculates the amount of matter in a phase, flow or a body of
    %   matter. Therfore input arguments have to be either a |matter.phase|
    %   object, a |matter.flow| object or matter data formatted and in the
    %   order shown below. If the input argument is a flow, then the output
    %   will be a flow rate in [mol/s]. 
    %   The function calculates the amount of each substance by dividing
    %   the masses of each individual substance by their respective molar
    %   mass and then adding all molar masses.
    %
    % calculateMols returns
    %  fAmount - A float number depicting either the amount of matter in
    %     [mol] or the matter flow in [mol/s] if the input argument is a
    %     |matter.flow| object.

    if isa(varargin{1}, 'matter.phase')
        % initialize attributes from input object - get afMass from phase obj
        afMass = varargin{1}.afMass;

    elseif isa(varargin{1}, 'matter.flow')
        % Flow object - return will be mol/s. Not an absolute mass given as for
        % phase, but the partial/substance mass flows in kg/s.
        afMass = varargin{1}.arPartialMass * varargin{1}.fFlowRate;

    % Make sure its numeric and a row vector and has the right number of masses
    elseif isnumeric(varargin{1}) && (size(varargin{1}, 1) == 1) && (size(varargin{1}, 2) == this.iSubstances)
        % Case two - matter data given. Needs to be in the following format and order:
        % substance masses (array of floats)
        afMass  = varargin{1};

    else
        this.throw('calculateMols', 'If only one param provided, has to be a matter.phase or matter.flow (derivative) or a row vector with partial masses');
    end

    % Calculating the number of mols for each species
    afMols = afMass ./ this.afMolarMass;

    % Calculating the total number of mols
    fAmount = sum(afMols);

end
