function fMolAmount = calculateMolAmount(this, varargin) % afMasses)
    %CALCULATEMOLAMOUNT Calculates the amount of matter in mol
    %   Calculates the amount of matter in a phase, flow or a body of
    %   matter. Therfore input arguments have to be either a |matter.phase|
    %   object, a |matter.flow| object or matter data formatted and in the
    %   order shown below. If the input argument is a flow, then the output
    %   will be a flow rate in [mol/s].
    %   
    %   The function calculates the amount of each substance by dividing
    %   the masses of each individual substance by their respective molar
    %   mass and then adding all molar masses.
    %
    %
    % calculateMols returns
    %  fAmount - A float number depicting either the amount of matter in
    %     [mol] or the matter flow in [mol/s] if the input argument is a
    %     |matter.flow| object.
    %
    %
    %TODO: simplify this method by only handling absolute input values,
    %      i.e. move the matter object-specific code to the corresponding
    %      classes

    % Handle two variants of calling this method: With an object where the
    % necessary data can be retrieved from, or the data itself.
    if strcmp(varargin{1}.sObjectType, 'phase')
        %TODO: Delete this part and put it into the corresponding classes
        %      instead (the matter table should not know about other
        %      objects).

        % Get data from object: |afMasses| array from |matter.phase| object
        afMasses = varargin{1}.afMass;

    elseif strcmp(varargin{1}.sObjectType, 'flow')
        %TODO: Delete this part and put it into the corresponding classes
        %      instead (the matter table should not know about other
        %      objects). Also, it is confusing that this method may return
        %      different units depending on input (see below).

        % Get data from object: |afMasses| array from |matter.flow| object
        % Return value will be in [mol/s]. Here, the fraction of mass flow
        % rates for each substance multiplied by the total mass flow rate
        % is used (instead of using an absolute mass).
        afMasses = varargin{1}.arPartialMass * varargin{1}.fFlowRate;

    elseif isnumeric(varargin{1})
        % If the input is numeric, ...

        % ... make sure it has the expected size.
        assert(isequal(size(varargin{1}), [1, this.iSubstances]), ...
            'Input must be a row vector and the number of rows equal to the number of recognized substances.');

        % The given parameter is the masses array.
        afMasses = varargin{1};

    else
        this.throw('calculateMols', 'Parameter must be of type |double|, |matter.phase| or |matter.flow|.');
    end

    % Calculating the (mole) amount of each substance, then taking the sum
    % to get the total amount of substance in [mol] (or in [mol/s] if input
    % object is a |matter.flow|).
    fMolAmount = sum(afMasses ./ this.afMolarMass);

end
