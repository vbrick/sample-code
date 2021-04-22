/*
 * Reference
 * https://docs.microsoft.com/en-us/dotnet/standard/serialization/system-text-json-converters-how-to?pivots=dotnet-core-3-1#sample-basic-converter
 * */
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace VBrick.ConsoleApp.Processing
{
    /// <summary>
    /// Converts between a TimeSpan and a specific time string format.
    /// </summary>
    public class TimeSpanJsonConverter : JsonConverter<TimeSpan>
    {
        private const string TIME_FORMAT = "c";

        public override TimeSpan Read(
            ref Utf8JsonReader reader,
            Type typeToConvert,
            JsonSerializerOptions options) =>
                TimeSpan.ParseExact(reader.GetString(),
                    TIME_FORMAT, CultureInfo.InvariantCulture);

        public override void Write(
            Utf8JsonWriter writer,
            TimeSpan timeSpanValue,
            JsonSerializerOptions options) =>
                writer.WriteStringValue(timeSpanValue.ToString(
                    TIME_FORMAT, CultureInfo.InvariantCulture));
    }
}
