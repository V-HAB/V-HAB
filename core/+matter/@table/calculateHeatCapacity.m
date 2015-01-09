function fHeatCapacity = calculateHeatCapacity(this, varargin)
%CALCULATEHEATCAPACITY Summary of this function goes here
% Calculates the total heat capacity by adding the single
% substance capacities weighted with their mass fraction. (Same
% as in calcMolMass) Can use either a phase object as input
% parameter, or the phase type (sType) and the masses array
% (afMass). Optially temperature and pressure can be passed as
% third and fourth parameters, respectively.
%
% calculateHeatCapacity returns
%  fHeatCapacity  - specific, isobaric heat capacity of mix in J/kgK 

fHeatCapacity = -1;

% Case one - just a phase object provided
if length(varargin) == 1
    if ~isa(varargin{1}, 'matter.phase')
        this.throw('fHeatCapacity', 'If only one param provided, has to be a matter.phase (derivative)');
    end
    
    % initialise attributes from phase object
    sPhase  = varargin{1}.sType;
    sName = varargin{1}.sName;
    afMass = varargin{1}.afMass;
    fT = varargin{1}.fTemp;
    fP = varargin{1}.fPressure;
    if isempty(fP); fP = this.Standard.Pressure; end; % std pressure (Pa)
    
    % if no mass given also no heatcapacity possible
    if varargin{1}.fMass == 0 || sum(isnan(afMass)) == length(afMass)
        fHeatCapacity = 0;
        return;
    end
    
    % not used
    %sId    = [ 'Phase ' varargin{1}.oStore.sName ' -> ' varargin{1}.sName ];
    
    % Assuming we have two or more params, the phase type, a vector with
    % the mass of each substance and current temperature and pressure
    %CHECK: As far as I can see, only matter.flow.m uses this,
    %could change that file and get rid of this if condition.
else
    sPhase  = varargin{1};
    %sName = 'manual'; % can be anything else, just used for check of last attributes
    afMass = varargin{2};
    
    % if no mass given also no heatcapacity possible
    if sum(afMass) == 0 || sum(isnan(afMass)) == length(afMass)
        fHeatCapacity = 0;
        return;
    end
    
    % if additional temperature and pressure given
    if nargin > 2
        fT = varargin{3};
        fP = varargin{4};
    else
        fT = this.Standard.Temperature; % std temperature (K)
        fP = this.Standard.Pressure;    % std pressure (Pa)
    end
    
    % not used
    %sId = 'Manually provided vector for substance masses';
end

% Commented the following lines, handling of the decision
% incompressible/compressible is done in the phases for now.

%             % fluids and/or solids are handled as incompressible usually
%             % can be changed over the public properties bLiquid and bSolid
%             if strcmpi(sType, 'liquid') && this.bLiquid
%                 fP = 100000;
%             elseif strcmpi(sType, 'solid') && this.bSolid
%                 fP = 100000;
%             end

% initialise attributes for next run (only done first time)
%             if ~isfield(this.cfLastProps, 'fCp')
%                 this.cfLastProps.fT     = fT;
%                 this.cfLastProps.fP     = fP;
%                 this.cfLastProps.afMass = afMass;
%                 this.cfLastProps.fCp    = 0;
%                 this.cfLastProps.sPhase  = sPhase;
%                 this.cfLastProps.sName  = sName;
%             end

% if same Phase and Type as lasttime, it has to be checked if
% temperature, pressure or mass has changed more than x% from
% last time
% percentage of change can be handled over the public property
% rMaxChange; std is 0.01 (1%)
%disp(['phase: ', sPhase,' substance ', sName]);
%             if strcmp(sPhase, this.cfLastProps.sPhase) && strcmp(sName, this.cfLastProps.sName)
%                 % Could the above condition be fooled by non-unique phase
%                 % names?
%                 aCheck{1} = [fT; this.cfLastProps.fT];
%                 aCheck{2} = [fP; this.cfLastProps.fP];
%                 aCheck{3} = [afMass; this.cfLastProps.afMass];
%                 aDiff = cell(1,length(aCheck));
%                 for i=1:length(aCheck)
%                     if aCheck{i}(1,:) ~= 0
%                         aDiff{i} = abs(diff(aCheck{i})/aCheck{i}(1,:));
%                     else
%                         aDiff{i} = 0;
%                     end
%                 end
%                 % more than 1% difference (or what is defined in
%                 % rMaxChange) from last -> recalculate c_p and save
%                 % attributes for next run
%                 if any(cell2mat(aDiff) > this.rMaxChange)
%                     this.cfLastProps.fT = fT;
%                     this.cfLastProps.fP = fP;
%                     this.cfLastProps.afMass = afMass;
%                 else
%                     fHeatCapacity = this.cfLastProps.fCp;
%                     if fHeatCapacity
%                         return;
%                     end
%                 end
%             else
%                 this.cfLastProps.fT = fT;
%                 this.cfLastProps.fP = fP;
%                 this.cfLastProps.afMass = afMass;
%                 this.cfLastProps.sPhase = sPhase;
%                 this.cfLastProps.sName = sName;
%             end

% look which substances have mass so heatcapacity can calculated
%            if any(afMass > 0) % needed? should always true because of check in firstplace
aiIndexes = find(afMass>0);
% go through all substances that have mass and calculate the heatcapacity of each. then add this to the
% rest
keyboard();
for i=1:length(find(afMass>0))
    fCp = this.FindProperty(this.csSubstances{aiIndexes(i)}, 'Heat Capacity', 'Temperature', fT, 'Pressure', fP, sPhase);
    %fCp = this.FindProperty_old(fT, fP, this.csSubstances{aiIndexes(i)}, 'c_p', sType); % Old FindProperty
    fHeatCapacity = fHeatCapacity + afMass(aiIndexes(i)) ./ sum(afMass) * fCp;
end
% save heatcapacity for next call of this routine
%this.cfLastProps.fCp = fHeatCapacity;

%            end

% If none of the substances has a valid heatcapacity an error
% is thrown.
if (fHeatCapacity < 0 || isnan(fHeatCapacity)) && ~(sum(afMass) == 0)
    this.throw('calculateHeatCapacity','Error in HeatCapacity calculation!');
end
end