function calculateOpnameStatus(data, data) {
    if (data.glosZichtbaar === "1") {
        return "Verborgen";
    }

    if (!data.wie) {
        return "Niemand kent gebaar";
    }

    if (!data.signbank) {
        return "Signbank niet gekoppeld";
    }

    if (!data.actie) {
        return "Niet besproken";
    }

    if (!data.zelfopname) {
        return "Geen zelfopname";
    }

    if (data.fonologie_fase1 !== "1") {
        return "Geen fonologie in Signbank";
    }

    if (!gecontroleerd(data)) {
        return `${controlTotal}/${controlAantal} nog te controleren`;
    }

    if (!data.studioOpnameWie) {
        return "Niemand gekozen voor studio opname";
    }

    if (!data.videoCenter || !data.studioOpnameStatus) {
        return "Geen studioopname";
    }

    if (data.studioOpnameStatus === "1") {
        return "Klaar";
    }

    if (data.studioOpnameStatus === "2") {
        return "Studio opname afgekeurd";
    }

    console.log(data)
    return "Studio opname niet beoordeeld";
}



function gecontroleerd(data){
    //gebruikerslijkst ophalen van wie kent het gebaar
    //per gebruiker checken of er 1 is
    controlAantal = 0;
    controlTotal = 0;
    controlList2 = JSON.parse(data.control_nodig)
        for (var key in controlList2) {
            controlTotal++;
            if (controlList2.hasOwnProperty(key)) {
              var value = controlList2[key];
              console.log(key, value)
              if(value == '1')
              {
                controlAantal++
              }
    
            }}
    if(controlAantal == controlTotal && controlTotal >= 1)
    {
        return true;
    }
    else
    {
        return false;
    }
        }