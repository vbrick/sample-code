using System;
using System.Collections.Generic;
using System.Text;
using System.Text.Json.Serialization;
using VBrick.ConsoleApp.Processing;

namespace VBrick.ConsoleApp.Models
{
    public class VideoReport
    {
        /// <summary>
        /// Primary key for storing record into database
        /// </summary>
        [JsonIgnore]
        public Guid Id { get; set; }
        [JsonPropertyName("videoId")]
        public Guid VideoId { get; set; }
        [JsonPropertyName("title")]
        public string Title { get; set; }
        [JsonPropertyName("username")]
        public string Username { get; set; }
        [JsonPropertyName("firstName")]
        public string FirstName { get; set; }
        [JsonPropertyName("lastName")]
        public string LastName { get; set; }
        [JsonPropertyName("emailAddress")]
        public string EmailAddress { get; set; }
        [JsonIgnore]
        public string DepartmentOrSector { get; set; }
        [JsonIgnore]
        public string Group { get; set; }
        [JsonIgnore]
        public string Section { get; set; }
        [JsonPropertyName("completed")]
        public bool Completed { get; set; }
        [JsonPropertyName("zone")]
        public string Zone { get; set; }
        [JsonPropertyName("device")]
        public string Device { get; set; }
        [JsonPropertyName("browser")]
        public string Browser { get; set; }
        [JsonPropertyName("userDeviceType")]
        public string UserDeviceType { get; set; }
        [JsonPropertyName("playbackUrl")]
        public string PlaybackUrl { get; set; }
        [JsonPropertyName("dateViewed")]
        [JsonConverter(typeof(DateTimeOffsetJsonConverter))]
        public DateTimeOffset DateViewed { get; set; }
        [JsonPropertyName("viewingTime")]
        [JsonConverter(typeof(TimeSpanJsonConverter))]
        public TimeSpan ViewingTime { get; set; }
        [JsonPropertyName("viewingStartTime")]
        public DateTimeOffset ViewingStartTime { get; set; }
        [JsonPropertyName("viewingEndTime")]
        public DateTimeOffset ViewingEndTime { get; set; }

        public override string ToString()
        {
            return String.Format("{{\"Id\":\"{0}\", \"Title\":\"{1}\", \"DateViewed\":\"{2}\"}}", this.Id, this.Title, this.DateViewed.ToString("O"));
        }
    }
}
