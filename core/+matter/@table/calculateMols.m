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

    % Case one - just a phase or flow object provided
    if length(varargin) == 1

        if ~isa(varargin{1}, 'matter.phase')  && ~isa(varargin{1}, 'matter.flow')
            this.throw('calculateMols', 'If only one param provided, has to be a matter.phase or matter.flow (derivative)');
        end

        % initialize attributes from input object
        % Getting the phase type (gas, liquid, solid) depending on the object
        % type, also setting the afMass array.
        if isa(varargin{1}, 'matter.phase')
            afMass = varargin{1}.afMass;
        elseif isa(varargin{1}, 'matter.flow')
            afMass = varargin{1}.arPartialMass * varargin{1}.fFlowRate;
        end

    else
        % Case two - matter data given. Needs to be in the following format and order:
        % substance masses (array of floats)

        afMass  = varargin{1};

    end

    % Calculating the number of mols for each species
    afMols = afMass ./ this.afMolarMass;

    % Calculating the total number of mols
    fAmount = sum(afMols);

end
