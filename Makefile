#define _POSIX_C_SOURCE 199309L

#include<stdlib.h>
#include<stdint.h>
#include<stdio.h>
#include<string.h>
#include<libusb-1.0/libusb.h>
#include<math.h>
#include<time.h>
#include<errno.h>

struct profile{
    uint8_t profile1[69];
    uint8_t profile2[69];
    uint8_t profile3[69];
    uint8_t profile4[69];
    uint8_t profile5[69];
    uint8_t dbt; // Debounce Time (This is global and not profile specific)
};

int convertToDataArray(char text[], uint8_t **localdata);
int setDefaultState(libusb_device_handle *handle);
libusb_device_handle* openDevice(void);
int closeDevice(libusb_device_handle* handle);
int getProfileData(libusb_device_handle *handle, int profile, uint8_t *data);
int writeProfileData(libusb_device_handle *handle, uint8_t *data);
uint8_t getDebounceTime(libusb_device_handle *handle);
void listProfileSettings(struct profile *p, int profile);
int setDebounceTime(libusb_device_handle *handle, uint8_t dbT);
int parseIntArg(const char *text, int minimum, int maximum, int *value);

const uint16_t VID = 0x1e7d;
const uint16_t PID = 0x2c88;
int errCheck = 0;

int parseIntArg(const char *text, int minimum, int maximum, int *value)
{
    char *end = NULL;
    errno = 0;
    long parsed = strtol(text, &end, 10);
    if(errno != 0 || text[0] == '\0' || end == NULL || *end != '\0' ||
       parsed < minimum || parsed > maximum)
        return 1;
    *value = (int)parsed;
    return 0;
}


int main(int argc, char *argv[])
{
    
    if(argc < 2 || !strcmp(argv[1],"--help"))
    {
        printf("Usage: konepro OPTIONS\nOPTIONS:\n-l R G B // Left Click Colour (values 0 to 255)\n-r R G B // Right Click Colour (values 0 to 255)\n");
        printf("-lm value // LED Mode (0=Off,1=Fully lit,2=blinking,3=breathing,4=Heartbeat,9=Aimo Intelligent,10=Wave)\n-lb value // LED Brightness (0 to 255)\n");
        printf("-ls value // LED Speed (1 to 11)\n");
        printf("-list profile // List Profile Settings (0 to 4)\n");
        printf("-list-all // List all five onboard profiles\n");
        printf("-p value // Polling Rate (0 to 3; 125,250,500,1000)\n");
        printf("-p-all value // Set Polling Rate on all five profiles\n");
        printf("-d dpi switch // DPI (minimum: 50, maximum 19,000, increments of 50), switch(0 to 4)(Defaults to 0 if not spcified)\n-ds value // DPI Switcher (0 to 4)\n");
        printf("-prf value // Profile to change (value 0 to 4) Defaults to 0 if omitted\n");
        printf("-default // Factory reset Device\n");
        printf("-dbt value // Sets Debounce Time in milliseconds (value 0 to 10)\n");
        return 0;
    }
    
    int checkProfile = 0;
    for(int i = 0; argv[i] != NULL; i++)
    {
        if(!strcmp(argv[i],"-prf") && i+1 < argc){
            if(parseIntArg(argv[i+1], 0, 4, &checkProfile) != 0)
            {
                printf("Invalid profile (expected 0 to 4)\n");
                return 1;
            }
            break;
        }
    }

    libusb_device_handle *devHandle = openDevice();
    if(devHandle == NULL)
    {
        printf("Failed to open device\n");
        return 1;
    }


    struct profile profiles;
    errCheck = getProfileData(devHandle,0,profiles.profile1);
    if(errCheck != 0){
        printf("getProfileData Failed\n");
        goto FailState;
    }
    errCheck = getProfileData(devHandle,1,profiles.profile2);
    if(errCheck != 0){
        printf("getProfileData Failed\n");
        goto FailState;
    }
    errCheck = getProfileData(devHandle,2,profiles.profile3);
    if(errCheck != 0){
        printf("getProfileData Failed\n");
        goto FailState;
    }
    errCheck = getProfileData(devHandle,3,profiles.profile4);
    if(errCheck != 0){
        printf("getProfileData Failed\n");
        goto FailState;
    }
    errCheck = getProfileData(devHandle,4,profiles.profile5);
    if(errCheck != 0){
        printf("getProfileData Failed\n");
        goto FailState;
    }
    profiles.dbt = getDebounceTime(devHandle);
    if(profiles.dbt == 11){
        printf("getDebounceTime Failed\n");
        goto FailState;
    }
    
    uint8_t *currentSettings;
    int allPollingRate = -1;
    switch(checkProfile)
    {
        case 0:
            currentSettings = profiles.profile1;
            break;
        case 1:
            currentSettings = profiles.profile2;
            break;
        case 2:
            currentSettings = profiles.profile3;
            break;
        case 3:
            currentSettings = profiles.profile4;
            break;
        case 4:
            currentSettings = profiles.profile5;
            break;
        default:
            printf("Invalid Profile\n");
            closeDevice(devHandle);
            return 1;
    }
    //printf("%d\n",argc);
    //printf("%s\n", argv[0]);
    
    for(int i = 0; argv[i] != NULL; i++)
    {
        if(!strcmp(argv[i],"-l") && i+3 < argc)
        {
            int red, green, blue;
            if(parseIntArg(argv[i+1], 0, 255, &red) != 0 ||
               parseIntArg(argv[i+2], 0, 255, &green) != 0 ||
               parseIntArg(argv[i+3], 0, 255, &blue) != 0)
            {
                printf("Invalid left RGB value (expected 0 to 255)\n");
                goto FailState;
            }
            currentSettings[38] = (uint8_t)red; // left click RGB
            currentSettings[39] = (uint8_t)green;
            currentSettings[40] = (uint8_t)blue;
               
        }
        else if(!strcmp(argv[i],"-r") && i+3 < argc)
        {
            int red, green, blue;
            if(parseIntArg(argv[i+1], 0, 255, &red) != 0 ||
               parseIntArg(argv[i+2], 0, 255, &green) != 0 ||
               parseIntArg(argv[i+3], 0, 255, &blue) != 0)
            {
                printf("Invalid right RGB value (expected 0 to 255)\n");
                goto FailState;
            }
            currentSettings[43] = (uint8_t)red; // right click RGB
            currentSettings[44] = (uint8_t)green;
            currentSettings[45] = (uint8_t)blue;
            
        }
        else if(!strcmp(argv[i],"-p") && i+1 < argc)
        {
            int pollingRate;
            if(parseIntArg(argv[i+1], 0, 3, &pollingRate) != 0)
            {
                printf("Invalid polling rate (expected 0 to 3)\n");
                goto FailState;
            }
            currentSettings[29] = (uint8_t)pollingRate;
        }
        else if(!strcmp(argv[i],"-p-all") && i+1 < argc)
        {
            if(parseIntArg(argv[i+1], 0, 3, &allPollingRate) != 0)
            {
                printf("Invalid polling rate (expected 0 to 3)\n");
                goto FailState;
            }
        }
        else if(!strcmp(argv[i], "-lm") && i+1 < argc)
        {
            int ledMode;
            if(parseIntArg(argv[i+1], 0, 10, &ledMode) != 0)
            {
                printf("Invalid LED mode\n");
                goto FailState;
            }
            currentSettings[30] = (uint8_t)ledMode;
            uint8_t validSettings[] = {0,1,2,3,4,9,10};
            for(int i = 0; i < 7; i++){
                if(currentSettings[30] == validSettings[i]) goto FoundValidSetting;
            }
            goto FailState;
            FoundValidSetting:
                //printf("FoundValidSetting Triggered\n");
                continue;
        }
        else if(!strcmp(argv[i], "-lb") && i+1 < argc)
        {
            int brightness;
            if(parseIntArg(argv[i+1], 0, 255, &brightness) != 0)
            {
                printf("Invalid LED brightness (expected 0 to 255)\n");
                goto FailState;
            }
            currentSettings[32] = (uint8_t)brightness;
        }
        else if(!strcmp(argv[i], "-d") && i+1 < argc)
        {

            int dpi;
            int swtch = 0;
            if(parseIntArg(argv[i+1], 50, 19000, &dpi) != 0 || dpi % 50 != 0)
            {
                printf("Invalid DPI (expected 50 to 19000 in steps of 50)\n");
                goto FailState;
            }
            if(argc > i+2 && argv[i+2][0] != '-')
            {
                if(parseIntArg(argv[i+2], 0, 4, &swtch) != 0)
                {
                    printf("Invalid DPI switch (expected 0 to 4)\n");
                    goto FailState;
                }
            }
            int switchMod = 2 * swtch;
            currentSettings[7+switchMod] = ((dpi/50) % 256);                 // Switch 1 to 4 is +2 elements from the first byte of the previous Switch
            currentSettings[8+switchMod] = (((dpi/50)-currentSettings[7+switchMod]) / 256);
            
        }
        else if(!strcmp(argv[i], "-ds") && i+1 < argc)
        {
            int dpiSwitch;
            if(parseIntArg(argv[i+1], 0, 4, &dpiSwitch) != 0)
            {
                printf("Invalid active DPI switch (expected 0 to 4)\n");
                goto FailState;
            }
            currentSettings[6] = (uint8_t)dpiSwitch;
        }
        else if(!strcmp(argv[i], "-default"))
        {
            errCheck = setDefaultState(devHandle); // Factory Reset
            if(errCheck != 0)
            {
                printf("setDefaultState Failed\n");
                closeDevice(devHandle);
                return 1;
            }
            closeDevice(devHandle);
            return 0;
        }
        else if(!strcmp(argv[i], "-list") && i+1 < argc)
        {
            int profileToList;
            if(parseIntArg(argv[i+1], 0, 4, &profileToList) != 0)
            {
                printf("Invalid profile (expected 0 to 4)\n");
                goto FailState;
            }
            listProfileSettings(&profiles, profileToList);
            closeDevice(devHandle);
            return 0;
        }
        else if(!strcmp(argv[i], "-list-all"))
        {
            for(int profile = 0; profile < 5; profile++)
                listProfileSettings(&profiles, profile);
            closeDevice(devHandle);
            return 0;
        }
        else if (!strcmp(argv[i],"-ls") && i+1 < argc)
        {
            int speed;
            if(parseIntArg(argv[i+1], 1, 11, &speed) != 0)
            {
                printf("Invalid LED speed (expected 1 to 11)\n");
                goto FailState;
            }
            currentSettings[31] = (uint8_t)speed;
        }
        else if(!strcmp(argv[i],"-dbt") && i+1 < argc)
        {
            int debounce;
            if(parseIntArg(argv[i+1], 0, 10, &debounce) != 0)
            {
                printf("Invalid debounce time (expected 0 to 10)\n");
                goto FailState;
            }
            errCheck = setDebounceTime(devHandle,(uint8_t)debounce);
            if(errCheck != 0){
                printf("setDebounceTime Failed\n");
                closeDevice(devHandle);
                return 1;
            }

            //closeDevice(devHandle);
            //return 0;
        }
        
    }
    if(allPollingRate >= 0)
    {
        uint8_t *allProfiles[] = {
            profiles.profile1,
            profiles.profile2,
            profiles.profile3,
            profiles.profile4,
            profiles.profile5,
        };
        for(int profile = 0; profile < 5; profile++)
        {
            allProfiles[profile][29] = (uint8_t)allPollingRate;
            if(writeProfileData(devHandle, allProfiles[profile]) != 0)
            {
                printf("Failed to write profile %d\n", profile);
                goto FailState;
            }
        }
        printf("Polling rate set to %dHz on all profiles\n", 125 * (1 << allPollingRate));
    }
    else if(writeProfileData(devHandle, currentSettings) != 0)
    {
        printf("Failed to write profile %d\n", checkProfile);
        goto FailState;
    }
    
    errCheck = closeDevice(devHandle);
    if(errCheck != 0)
    {
        printf("Close device Failed");
        return 1;
    }
    return 0;

    FailState:
        closeDevice(devHandle);
        printf("FailState Triggered\n");
        return 1;
}

int convertToDataArray(char text[], uint8_t **localdata)
{
    int track = 0;
    char mainTmp[999][5];
    ((*localdata)) = malloc(999 * sizeof(uint8_t));
    if((*localdata) == NULL)
    {
        printf("Failed to allocate memory\n");
        return 1;
    }
    
    for(int byteTrack = 0; text[byteTrack] != '\0'; track++, byteTrack += 2)
    {
        mainTmp[track][0] = '0';
        mainTmp[track][1] = 'x';
        mainTmp[track][2] = text[byteTrack];
        mainTmp[track][3] = text[byteTrack+1];
        mainTmp[track][4] = '\0';
    }
    for(int i = 0; i < track; i++)
    {
        (*localdata)[i] = (uint8_t)strtol(mainTmp[i],NULL,0);
    }
    uint8_t *tmp = realloc((*localdata), track * sizeof(uint8_t));
    if(tmp == NULL)
    {
        printf("Failed to reallocate memory\n");
        free((*localdata));
        return 1;
    }
    (*localdata) = tmp;
    return 0;
}

int setDefaultState(libusb_device_handle *handle)
{
    char defaultPreset[] = "090801000000000000";
    uint8_t *data;
    errCheck = convertToDataArray(defaultPreset,&data);
    if(errCheck != 0)
    {
        printf("convertToDataArray failed\n");
        //closeDevice(handle);
        return 1;
    }

    int errorCheck = libusb_control_transfer(handle,0x21,0x09,0x0309,0x0003,data,0x0009,10000);
    if(errorCheck < 0){
        printf("Control Transfer Failed\n");
        return 1;
    }
    free(data);
    //closeDevice(handle); -- Device is closed after the function is called in the main function.
    return 0;
}

libusb_device_handle* openDevice(void)
{
    errCheck = libusb_init(NULL);
    if(errCheck != 0)
    {
        printf("Init error");
        return NULL;
    }
    
    libusb_device_handle *devHandle = libusb_open_device_with_vid_pid(NULL,VID,PID);
    if(devHandle == NULL)
    {
        printf("Device Handle Error\n");
        return NULL;
    }

    /* Let libusb detach interface 3 only when necessary and reattach it when
     * released. The old code incorrectly failed when no driver was attached. */
    errCheck = libusb_set_auto_detach_kernel_driver(devHandle, 1);
    if(errCheck != 0 && errCheck != LIBUSB_ERROR_NOT_SUPPORTED)
    {
        printf("%s (auto detach kernel driver)\n", libusb_error_name(errCheck));
        libusb_close(devHandle);
        libusb_exit(NULL);
        return NULL;
    }
    
    errCheck = libusb_claim_interface(devHandle, 3);
    if(errCheck != 0)
    {
        printf("%s (claim interface)\n", libusb_error_name(errCheck));
        libusb_close(devHandle);
        libusb_exit(NULL);
        return NULL;
    }
    return devHandle;
}

int closeDevice(libusb_device_handle* handle)
{
    errCheck = libusb_release_interface(handle,3);
    if(errCheck != 0)
    {
        printf("%s\n (release interface)",libusb_error_name(errCheck));
        //return 1;
    }
    
    libusb_close(handle);

    libusb_exit(NULL);

    return 0; 
}

int getProfileData(libusb_device_handle *handle, int profile, uint8_t *data)
{
    // PROFILE = 0 to 4
    char *profileString = "04008000";
    u_int8_t *profileData;
    errCheck = convertToDataArray(profileString,&profileData);
    if(errCheck != 0)
    {
        return 1;
    }
    profileData[1] = profile;
    
    /*
   Setup Data
    bmRequestType: 0x21
    bRequest: SET_REPORT (0x09)
    wValue: 0x0304
        ReportID: 4
        ReportType: Feature (3)
    wIndex: 3
    wLength: 4
    Data Fragment: 04 00 80 00
   */

    int errorCheck = libusb_control_transfer(handle,0x21,0x09,0x0304,0x0003,profileData,0x0004,1000); //SPECIFY WHICH PROFILE I WANT TO RETRIEVE
    if(errorCheck < 0){
        printf("Control transfer Failed\n");
        return 1;
    }

    /* Firmware 1.18 does not update report 6 synchronously. Reading it
     * immediately can return a partially updated or previous profile. */
    const struct timespec profileSwitchDelay = { .tv_sec = 0, .tv_nsec = 75000000 };
    nanosleep(&profileSwitchDelay, NULL);
    /*
    Setup Data
    bmRequestType: 0xa1
    bRequest: GET_REPORT (0x01)
    wValue: 0x0306
        ReportID: 6
        ReportType: Feature (3)
    wIndex: 3
    wLength: 69
    */
    
    errorCheck = libusb_control_transfer(handle,0xa1,0x01,0x0306,0x0003,data,0x0045,1000); //RETRIEVE PROFILE DATA
    if(errorCheck != 0x0045){
        printf("Profile %d read failed: %s (%d bytes)\n", profile,
               errorCheck < 0 ? libusb_error_name(errorCheck) : "short read",
               errorCheck);
        return 1;
    }

    int checksum = 0;
    for(int i = 0; i < 67; i++)
        checksum += data[i];
    if(data[0] != 0x06 || data[67] != checksum % 256 ||
       data[68] != (checksum - data[67]) / 256 || data[29] > 3)
    {
        printf("Profile %d returned invalid data; refusing to write it back\n", profile);
        return 1;
    }
    free(profileData);
    return 0;

}

int writeProfileData(libusb_device_handle *handle, uint8_t *data)
{
    int sum = 0;
    for(int i = 0; i < 67; i++)
        sum += data[i];
    data[67] = sum % 256;
    data[68] = (sum - data[67]) / 256;

    int result = libusb_control_transfer(handle, 0x21, 0x09, 0x0306,
                                         0x0003, data, 0x0045, 10000);
    if(result != 0x0045)
    {
        printf("Control transfer failed: %s (%d bytes)\n",
               result < 0 ? libusb_error_name(result) : "short write", result);
        return 1;
    }
    const struct timespec profileWriteDelay = { .tv_sec = 0, .tv_nsec = 75000000 };
    nanosleep(&profileWriteDelay, NULL);
    return 0;
}

void listProfileSettings(struct profile *p, int profile)
{
    uint8_t *listThisProfile;
    switch(profile)
    {
        case 0:
            listThisProfile = p->profile1;
            break;
        case 1:
            listThisProfile = p->profile2;
            break;
        case 2:
            listThisProfile = p->profile3;
            break;
        case 3:
            listThisProfile = p->profile4;
            break;
        case 4:
            listThisProfile = p->profile5;
            break;
        default:
            printf("Invalid profile\n");
            return;
    }

    //int dpi = (listThisProfile[7] * 50) + ((listThisProfile[8] * 256) * 50);
    printf("Profile %d\n", profile);
    printf("DPI: ");
    for(int i = 0,dpiSwitch = 0; dpiSwitch < 5;dpiSwitch++, i+=2)
    {
        printf("%d(Switch %d), ", (listThisProfile[7+i] * 50) + ((listThisProfile[8+i] * 256) * 50),dpiSwitch);
    }
    printf("\n");
    printf("Active DPI Switch: %d\n", listThisProfile[6]);
    printf("Left RGB: %d %d %d\n", listThisProfile[38],listThisProfile[39], listThisProfile[40]);
    printf("Right RGB: %d %d %d\n", listThisProfile[43],listThisProfile[44],listThisProfile[45]);
    printf("Polling Rate: %dHz\n", (int)(125 * (pow(2.0,(double)listThisProfile[29]))));
    printf("LED Mode: %d, (0 = 0ff, 1 = Fully lit, 2 = Blinking, 3 = Breathing, 4 = Heartbeat, 9 = Aimo Intelligent, 10 = Wave)\n", listThisProfile[30]);
    printf("LED Brightness: %d\n", listThisProfile[32]);
    printf("LED Speed: %d\n", listThisProfile[31]);
    printf("Debounce Time: %d ms (Global not profile specific)\n", p->dbt);
}

int setDebounceTime(libusb_device_handle *handle, uint8_t dbT)
{
    /*
    Setup Data
    bmRequestType: 0x21
    bRequest: SET_REPORT (0x09)
    wValue: 0x0311
    wIndex: 3
    wLength: 13
    Data Fragment: 110d0000000000000000001e00
    */
    if(dbT > 10) return 1;

    char *debounceString = "110d0000000000000000001e00";
    uint8_t *debounceData;
    errCheck = convertToDataArray(debounceString, &debounceData);
    if(errCheck != 0){
        printf("convertToDataArray Failed");
        return 1;
    }
    debounceData[2] = dbT; // Set debounce time 0 to 10
    int sum = 0;
    for(int i = 0; i < 11; i++){
        sum += debounceData[i];
    }
    debounceData[11] = sum; // Chekcsum
    int errorCheck = libusb_control_transfer(handle,0x21,0x09,0x0311,0x0003,debounceData,0x000d,1000);
    if(errorCheck < 0){
        printf("Control Transfer Failed\n");
        return 1;
    }
    free(debounceData);
    return 0;
}

uint8_t getDebounceTime(libusb_device_handle *handle)
{
   uint8_t dbtArray[13];

    /*
    Setup Data
    bmRequestType: 0xa1
    bRequest: GET_REPORT (0x01)
    wValue: 0x0311
    wIndex: 3
    wLength: 13
    */
   int errorCheck = libusb_control_transfer(handle,0xa1,0x01,0x0311,0x0003,dbtArray,0x000d,1000);
   if(errorCheck < 0){
        printf("Control Transfer Failed\n");
       return 11;
   }
   return dbtArray[2];
}
