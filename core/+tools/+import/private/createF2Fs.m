function tCurrentSystem = createF2Fs(tCurrentSystem, csF2F, sSystemFile)
% This function adds the code for all F2Fs into the system file
fprintf(sSystemFile, '         %s Creating the F2F processors\n', '%%');

csInputValues.pipe          = {'fLength', 'fDiameter', 'fRoughness'};
csInputValues.fan_simple    = {'fMaxDeltaP', 'bReverse'};
csInputValues.fan           = {'fSpeedSetpoint', 'sDirection'};
csInputValues.pump          = {'fFlowRateSP'};
csInputValues.checkvalve    = {'bReversed', 'fPressureDropCoefficient'};
csInputValues.valve         = {'fFlowCoefficient', 'bOpen'};

for iF2FType = 1:length(csF2F)
    sF2F = csF2F{iF2FType};
    for iF2F = 1:length(tCurrentSystem.(sF2F))

        tF2F       = tCurrentSystem.(sF2F){iF2F};
        F2FName   = tools.normalizePath(tF2F.label);

        sInput = '';
        for iInputValue = 1:length(csInputValues.(sF2F))
            sInputName = csInputValues.(sF2F){iInputValue};
            if ~isempty(tF2F.(sInputName))
                sInput = [sInput, ', ', tF2F.(sInputName)];
            else
                error('In system %s in %s %s the property %s was not defined in draw io!', sSystemName, sF2F, F2FName, sInputName)
            end
        end
        fprintf(sSystemFile, ['          components.matter.', sF2F,'(this, ''', F2FName,'''', sInput,');\n']);

        tCurrentSystem.csComponentIDs{end+1} = tF2F.id;
    end
fprintf(sSystemFile, '\n');
end